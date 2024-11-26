import time
import os 
import cv2 
import queue
from natsort import natsorted
import numpy as np
import sys
import pickle
import threading
import pandas as pd
import matplotlib.pyplot as plt
import multiprocessing as mp
import psutil
import signal
import traceback
import setproctitle


"""Import the custom AGC library"""
agc_lib_path = os.path.join(os.path.dirname(__file__), 'AGC_lib')
sys.path.append(os.path.abspath(agc_lib_path))
from PyAGC import import_AGC_lib, AGC

AGC_lib = import_AGC_lib()

"""Import the custom Downsampling library"""
downsample_lib_path = os.path.join(os.path.dirname(__file__), 'downsample_lib')
sys.path.append(os.path.abspath(downsample_lib_path))
from PyDownsample import import_downsample_lib, downsample, downsample_buffer, downsample_pure_python

# Import the CPP downsample lib (with types, etc)
downsample_lib = import_downsample_lib()

# The FPS we have locked the camera to (as opposed to 206.65 in the settings)
CAM_FPS: float = 200

# The origial dimensions of the camera before downsampling 
CAM_IMG_DIMS: np.ndarray = np.array((480, 640))

# The power of 2 to downsample the recorded image by 
downsample_factor: int = 4

"""Write a frame and its info in the write queue to disk 
in the output_path directory and to the settings file"""
def write_frame(write_queue: queue.Queue, filename: str, generate_settingsfile: bool=True):
    # Ensure the output directory exists (if we are not running via signalcommunication)
    if(not os.path.exists(filename) and generate_settingsfile):
        os.makedirs(filename)

    # Initialize a settings file for per-frame settings to be written to if this 
    # script is not using signal communication
    if(generate_settingsfile is True): settings_file: object = open(f'{filename}_settingsHistory.csv', 'a')

    # Calculate the downsampled image shape
    downsampled_image_shape: tuple = CAM_IMG_DIMS >> downsample_factor

    # Create a contiguous memory buffer for to store downsampled images
    downsampled_buffer = np.zeros((CAM_FPS, *downsampled_image_shape), dtype=np.uint8)

    # Define a container for the settings file object, as this will change 
    # when using signalcom
    current_settingsfile: object = settings_file if generate_settingsfile else None

    # While we are recording
    while(True):  
        # Retrieve a tuple of (frame, frame_num) from the queue
        ret: tuple = write_queue.get()

        # If we didn't receive a frame, we are at the end 
        # of the video, finish writing
        if(ret is None):
            break
        
        # In this case, we passed FPS information 
        if(type(ret) is dict):
            # Construct the path to the FPS file from the name 
            # of the settings file 
            fps_file_path: str = current_settingsfile.name.replace('settingsHistory.csv', 'FPS.pkl')

            # Simply save this information and continue
            with open(fps_file_path, 'wb') as f:
                pickle.dump(ret, f)
            
            # Skip the rest of the loop work
            continue

        # Extract frame and its metadata
        frame_buffer, frame_num, settings_buffer = ret[0:3]

        # If the length is greater than two, we've passed it 
        # the filename (directory) to save under and the settings file
        if(len(ret) > 3): 
            # Retrieve the directory name and the settings file object
            filename, settings_file = ret[3:5]

            # If this is the first settings file 
            if(current_settingsfile is None):
                # Set the current one to be the new one 
                current_settingsfile = settings_file
            
            # Otherwise, if it's a new settingsfile, close the old 
            # and swap to the new
            elif(current_settingsfile.name != settings_file.name):
                # Close the old settings file
                current_settingsfile.close()

                # Set the current one to be the new one
                current_settingsfile = settings_file
        
        # Quickly check and ensure the output directory exists 
        # it always should, but I had an error where it didn't. 
        # must have been timing related
        if(not os.path.exists(filename)): os.mkdir(filename)

        # Print out the state of the write queue
        print(f'Camera queue size: {write_queue.qsize()}')

        # Downsample every frame in the frame buffer and populate the downsampled buffer 
        #downsample_buffer(frame_buffer, CAM_FPS, downsample_factor, downsampled_buffer, downsample_lib)
        
        for i in range(frame_buffer.shape[0]):
            downsample(frame_buffer[i], downsample_factor, downsampled_buffer[i], downsample_lib) 

        # Write the frame
        save_path: str = os.path.join(filename, f'{frame_num}.npy')
        np.save(save_path, downsampled_buffer)

        # Write the frame info to the existing csv file
        np.savetxt(current_settingsfile, settings_buffer, delimiter=',', fmt='%d')

    # Close the settings and frame timings files (if needed)
    if(not current_settingsfile.closed): current_settingsfile.close()

"""Unpack chunks of n captured frames. This is used 
   to reformat the memory-limitation required capture 
   buffer format into the single frame files the codebase 
   is built on at the end of a capture."""
def unpack_capture_chunks(path_to_frames: str):
    # Declare an accumulator variable to hold the real frame number 
    # of each frame when we resave it 
    frame_num: int = 0

    # First retrieve the frame buffer files
    frame_buffer_files: list = natsorted(os.listdir(path_to_frames))

    # Iterate over the frame buffer files
    for i, frame_buffer_file in enumerate(frame_buffer_files):
        print(f'Camera unpacking buffer: {i+1}/{len(frame_buffer_files)}')

        # Load in this buffer 
        frame_buffer: np.ndarray = np.load(os.path.join(path_to_frames, frame_buffer_file))

        # Assert we are unpacking a buffer and not a frame
        assert(len(frame_buffer.shape) == 3 and frame_buffer.shape[0] == CAM_FPS) 

        # Iterate over the frames in the buffer 
        for frame_idx in range(frame_buffer.shape[0]):
            # Construct the new path to save this file (all buffer files will be overwritten by these)
            save_path: str = os.path.join(path_to_frames, f'{frame_num}.npy')

            # Save the frame
            np.save(save_path, frame_buffer[frame_idx])

            # Increment the frame number
            frame_num += 1 


"""Parse the setting file for a video as a data frame"""
def parse_settings_file(path: str) -> pd.DataFrame:
    return pd.read_csv(path, header=None, names=['gain_history', 'exposure_history'])

"""Read in a video from a folder full of images saved as .np files as 8-bit unsigned np.array"""
def vid_array_from_npy_folder(path: str) -> np.array:
    frames = [np.load(os.path.join(path, frame))
              for frame in natsorted(os.listdir(path))
              if('.pkl' not in frame and '.txt' not in frame)]
    
    return np.array(frames, dtype=np.uint8)

"""Read in a video from a image frames folder to an 8-bit unsigned np.array"""
def vid_array_from_img_folder(path: str) -> np.array:
    frames = [cv2.imread(os.path.join(path, frame)) 
              for frame in natsorted(os.listdir(path)) 
              if '.pkl' not in frame and '.txt' not in frame] 
    
    return np.array(frames, dtype=np.uint8)

"""Construct a video from a series of frames, output to output_path"""
def reconstruct_video(video_frames: np.array, output_path: str):
    # Define the information about the video to use for writing
    fps = CAM_FPS  
    height, width = video_frames[0].shape[:2]

    # Initialize VideoWriter object to write frames to
    out = cv2.VideoWriter(output_path, 0, fps, (width, height), 
                          isColor=len(video_frames.shape) > 3)

    # Write all of the frames to the video
    for i in range(video_frames.shape[0]):
        out.write(video_frames[i])

    # Release the VideoWriter object
    out.release()

"""A helper function that contains the meat of capturing 
   a video of a set length, for use when communicating 
   via signals"""
def capture_helper(cam: object, duration: float, write_queue: queue.Queue,
                  current_gain: float, current_exposure: float,
                  gain_change_interval: float,
                  frame_buffer: np.ndarray, settings_buffer: np.ndarray,
                  filename: str, settings_file: object, 
                  burst_num: int) -> None:
    print('World Cam: Beginning capture')

    # Begin timing capture
    start_capture_time: float = time.time()
    last_gain_change: float = start_capture_time 

    # Capture duration (seconds) of frames
    frame_num: int = 0
    while(True):
        # Capture the current time
        current_time: float = time.time()
        
        # If reached desired duration, stop recording
        if((current_time - start_capture_time) >= duration):
            break  

        # Capture the frame and splice only the odd cols (even cols have junk content)
        frame: np.array = cam.capture_array('raw')[:, 1::2]

        # Store the frame + settings into the allocated memory buffers
        frame_buffer[frame_num % CAM_FPS] = frame
        settings_buffer[frame_num % CAM_FPS] = (current_gain, current_exposure) 

        # Change gain every N ms
        if((current_time - last_gain_change) > gain_change_interval):
            # Take the mean intensity of the frame
            mean_intensity = np.mean(frame, axis=(0,1))
            
            # Feed the settings into the the AGC 
            ret = AGC(mean_intensity, current_gain, current_exposure, 0.95, AGC_lib)

            # Retrieve and set the new gain and exposure from our custom AGC
            #new_gain, new_exposure = ret['adjusted_gain'], int(ret['adjusted_exposure'])
            new_gain, new_exposure = 2, 4839
            
            cam.set_controls({'AnalogueGain': new_gain, 'ExposureTime': new_exposure}) 
            
            # Update the current_gain and current_exposure, 
            # wait for next gain change time
            last_gain_change = current_time
            current_gain, current_exposure = new_gain, new_exposure

        # Record the next frame number
        frame_num += 1 

        # If we have now captured one second worth of frames, send the frame buffer 
        # to be written 
        if(frame_num % CAM_FPS == 0):
            #write_queue.put((frame_buffer, frame_num, settings_buffer, frame_timings_buffer))
            write_queue.put((frame_buffer, frame_num, settings_buffer, filename, settings_file))
    
    # Record timing of end of capture 
    end_capture_time: float = time.time()
    
    # Calculate the approximate FPS the frames were taken at 
    # (approximate due to time taken for other computation)
    observed_fps: float = (frame_num)/(end_capture_time-start_capture_time)

    # Add this observed FPS to the write queue, to denote the FPS of the video 
    write_queue.put({"num_frames_captured": frame_num, "observed_fps": observed_fps})

    print(f'World cam: captured {frame_num} at ~{observed_fps} fps')


"""Record from with the camera with a specified duration, but 
   communicating with signals"""
def record_video_signalcom(duration: float, write_queue: queue.Queue, 
                           filename: str, initial_gain: float, initial_exposure: int,
                           stop_flag: threading.Event, is_subprocess: bool,
                           parent_pid: int, go_flag: threading.Event,
                           burst_num: int=0) -> None:

    # Retrieve the name of the controller this recorder is operating out of
    controller_name: str = setproctitle.getproctitle()
    
    # Define the path to the controller READY files
    READY_file_dir: str = "/home/rpiControl/combiExperiments/code/lightLogger/raspberry_pi_firmware/READY_files"

    # Define the name of this controller's READY file 
    READY_file_name: str = os.path.join(path, f"{controller_name}|READY")

    # Connect to and set up camera
    print(f"Initializing World camera")
    cam: Picamera2 = initialize_camera(initial_gain, initial_exposure)
    gain_change_interval: float = 0.250 # the time between AGC adjustments 
    
    # Begin Recording and capture initial metadata 
    cam.start("video")  
    initial_metadata: dict = cam.capture_metadata()
    current_gain, current_exposure = initial_metadata['AnalogueGain'], initial_metadata['ExposureTime']

    # Make absolutely certain Ae and AWB are off 
    # (had to put this here at some point) for it to work 
    cam.set_controls({'AeEnable':0, 'AwbEnable':0})

    # Initialize a contiguous memory buffer to store 1 second of frames 
    # + settings in this is so when we send them to be written, numpy does not have 
    # to reallocate for contiguous memory, thus slowing down capture
    frame_buffer: np.array = np.zeros((CAM_FPS, 480,640), dtype=np.uint8)
    settings_buffer: np.array = np.zeros((CAM_FPS, 2), dtype=np.float16)

    # If we were run as a subprocess, send a message to the parent 
    # process that we are ready to go via creating a file with the name of 
    # this controller
    try:
        if(is_subprocess is True):
            print(f'World Cam: Initialized. Generating READY flag file for parent: {parent_pid}')

            # Add a READY file for this controller
            with open(READY_file_name, 'w') as f: pass

            # While we have not receieved the GO signal wait 
            start_wait: float = time.time()
            last_read: float = time.time()
            while(not go_flag.is_set()):
                # Capture the current time
                current_wait: float = time.time()

                # If the parent process is no longer existent, something has gone wrong
                # and we should quit 
                if(not psutil.pid_exists(parent_pid)):
                    raise Exception('ERROR: Parent process was killed')
                
                # Every 2 seconds, output a message
                if((current_wait - last_read) >= 2):
                    print('World Cam: Waiting for GO signal...')
                    last_read = current_wait
    
    # Catch if there was an error in some part of the pipeline and we did not receive 
    # a go signal in the appropriate amount of time
    except Exception as e:
        # Close the camera 
        cam.close()

        # Print the traceback of the function calls that caused the error
        traceback.print_exc()
        print(e)
        sys.exit(1)

    # Now, the camera was initialized and the first ready was sent and the first go was received
    # Therefore, let's record the amount of time we desire
    
    # Define the starting burst number
    # and the thus the initial filename
    # settings file
    filename : str = filename.replace('burstX', f"burst{burst_num}") 
    settings_file: object = open(f'{filename}_settingsHistory.csv', 'a')

    # Once the GO signal has been received, begin capturing chunks until we 
    # receive a stop signal
    while(not stop_flag.is_set()):     
        # Use the milliseconds of time gaps between GO signals to generate files and hopefully not add 
        # any delay in the start of a burst capture
        # Akin to racing the beam on ATARI 2600, pretty cool! 

        #if(not os.path.exists(READY_file_name)): with open(READY_file_name, 'w') as f: pass

        # Generate the directory for this burst if it does not already exist
        if(not os.path.exists(filename)): os.mkdir(filename)
        
        # Generate/Open the settings file for this burst if it does not already exist
        if(settings_file.name != f'{filename}_settingsHistory.csv'): 
            settings_file = open(f'{filename}_settingsHistory.csv', 'a')

        # While we have the GO signal, record a burst
        while(go_flag.is_set()):
            # Capture duration worth of frames
            capture_helper(cam, duration, write_queue, current_gain, current_exposure,
                           gain_change_interval,
                           frame_buffer, settings_buffer,
                           filename, settings_file,
                           burst_num)

            # Stop recording until we receive the GO signal again 
            go_flag.clear()

            # Report to the parent process we are ready to go for the next burst 
            os.kill(parent_pid, signal.SIGUSR1)
            print(f'World cam: Finished burst: {burst_num+1} | Sending ready signal to parent: {parent_pid}!')
        
            # Increment the burst number += 1 
            burst_num += 1

            # Update the filename for the new burst number
            filename = filename.replace(f'burst{burst_num-1}', f"burst{burst_num}")

    # Append None to the write queue to signal it is time to stop 
    write_queue.put(None)

    # Stop recording and close the picam object 
    cam.close() 

    ## If the last dir we made never got used, remove it
    if(os.path.exists(filename) and len(os.listdir(filename)) == 0): os.rmdir(filename)

    # Close the settings file if it was never used for a burst
    # and thus wasn't closed in writing
    if(not settings_file.closed): settings_file.close()

    # Remove it as well if it is empty
    if(os.path.exists(settings_file.name) and os.path.getsize(settings_file.name) == 0): os.remove(settings_file.name)

    print(f'World cam: Finishing recording')
    

"""Record live from the camera with no specified duration"""
def record_live(duration: float, write_queue: queue.Queue, filename: str, 
                initial_gain: float, initial_exposure: int,
                stop_flag: threading.Event,
                is_subprocess: bool,
                parent_pid: int, 
                go_flag: threading.Event):
    from picamera2 import Picamera2

    # Connect to and set up camera
    print(f"Initializing World camera")
    cam: Picamera2 = initialize_camera(initial_gain, initial_exposure)
    gain_change_interval: float = 0.250 # the time between AGC adjustments 
    
    # Begin Recording and capture initial metadata 
    cam.start("video")  
    initial_metadata: dict = cam.capture_metadata()
    current_gain, current_exposure = initial_metadata['AnalogueGain'], initial_metadata['ExposureTime']
    
    # HARDCODE FOR A SPECIFIC TEST 
    #current_gain, current_exposure = 10, 4839

    # Make absolutely certain Ae and AWB are off 
    # (had to put this here at some point) for it to work 
    cam.set_controls({'AeEnable':0, 'AwbEnable':0})   

     # Initialize a contiguous memory buffer to store 1 second of frames 
    # + settings in this is so when we send them to be written, numpy does not have 
    # to reallocate for contiguous memory, thus slowing down capture
    #frame_buffer: np.array = np.zeros((CAM_FPS, 480, 640), dtype=np.uint8)
    frame_buffer: np.array = np.zeros((CAM_FPS, 480, 640), dtype=np.uint8)
    settings_buffer: np.array = np.zeros((CAM_FPS, 2), dtype=np.float32)
    #frame_timings_buffer: np.array = np.zeros((CAM_FPS,2), dtype=float) 
    #cpu_info_buffer: np.array = np.zeros((CAM_FPS,2), dtype=float) 


    # Initialize the last time we changed the gain as the current time
    last_gain_change: float = time.time()  

    # Capture indefinite frames
    frame_num: int = 0 
    while(not stop_flag.is_set()):
        # Capture the current time
        current_time: float = time.time()
        
        # Capture the frame and splice only the odd cols (even cols have junk content)
        frame: np.array = cam.capture_array('raw')[:, 1::2]

        # Store the frame + settings into the allocated memory buffers
        frame_buffer[frame_num % CAM_FPS] = frame
        settings_buffer[frame_num % CAM_FPS] = (current_gain, current_exposure)
   
        # Change gain every N ms
        if((current_time - last_gain_change) > gain_change_interval):
            # Take the mean intensity of the frame
            mean_intensity = np.mean(frame, axis=(0,1))
            
            # Feed the settings into the the AGC 
            ret = AGC(mean_intensity, current_gain, current_exposure, 0.95, AGC_lib)

            # Retrieve and set the new gain and exposure from our custom AGC
            #new_gain, new_exposure = ret['adjusted_gain'], int(ret['adjusted_exposure'])

            # HARD CODE FOR A SPECIFIC TEST 
            new_gain, new_exposure = 2, 4839

            cam.set_controls({'AnalogueGain': new_gain, 'ExposureTime': new_exposure}) 
            
            # Update the current_gain and current_exposure, 
            # wait for next gain change time
            last_gain_change = current_time
            current_gain, current_exposure = new_gain, new_exposure

        # Record the next frame number
        frame_num += 1 

        # If we have now captured one second worth of frames, send the frame buffer 
        # to be written 
        if(frame_num % CAM_FPS == 0):
            #write_queue.put((frame_buffer, frame_num, settings_buffer, frame_timings_buffer, cpu_info_buffer))
            write_queue.put((frame_buffer, frame_num, settings_buffer))


    # Signal the end of the write queue
    write_queue.put(None) 

    # Close the camera
    cam.close()

"""Record a viceo from the Raspberry Pi camera"""
def record_video(duration: float, write_queue: queue.Queue, filename: str, 
                 initial_gain: float, initial_exposure: int,
                 stop_flag: threading.Event,
                 is_subprocess: bool,
                 parent_pid: int,
                 go_flag: threading.Event): 
    from picamera2 import Picamera2

    # Connect to and set up camera
    try:
        print(f"Initializing world camera")
        cam: Picamera2 = initialize_camera(initial_gain, initial_exposure)
    except Exception as e:
        # Print the traceback to the series of function calls that led to the error 
        traceback.print_exc()
        print(e)
        sys.exit(1)

    # Define the time between AGC measurements
    gain_change_interval: float = 0.250 

    # Begin Recording and capture initial metadata 
    cam.start("video")  
    current_gain, current_exposure = initial_gain, initial_exposure

    # Make absolutely certain Ae and AWB are off 
    # (had to put this here at some point) for it to work 
    cam.set_controls({'AeEnable':0, 'AwbEnable':0})   

    # Initialize a contiguous memory buffer to store 1 second of frames 
    # + settings in this is so when we send them to be written, numpy does not have 
    # to reallocate for contiguous memory, thus slowing down capture
    frame_buffer: np.array = np.zeros((CAM_FPS, 480,640), dtype=np.uint8)
    settings_buffer: np.array = np.zeros((CAM_FPS, 2), dtype=np.float16)

    # If we were run as a subprocess, send a message to the parent 
    # process that we are ready to go
    try:
        if(is_subprocess): 
            print('World Cam: Initialized. Sending ready signal...')
            os.kill(parent_pid, signal.SIGUSR1)

            # While we have not receieved the GO signal wait 
            start_wait: float = time.time()
            last_read: float = time.time()
            while(not go_flag.is_set()):
                # Capture the current time
                current_wait: float = time.time()

                # If the parent process is no longer existent, something has gone wrong
                # and we should quit 
                if(not psutil.pid_exists(parent_pid)):
                    raise Exception('ERROR: Parent process was killed')
                
                # Every 2 seconds, output a message
                if((current_wait - last_read) >= 2):
                    print('World Cam: Waiting for GO signal...')
                    last_read = current_wait
    
    # Catch if there was an error in some part of the pipeline and we did not receive 
    # a go signal in the appropriate amount of time
    except Exception as e:
        # Close the camera 
        cam.close()

        # Print the traceback of the function calls that caused the error
        traceback.print_exc()
        print(e)
        sys.exit(1)
  

    # Once the go signal has been received, begin capturing
    print('World Cam: Beginning capture')

    # Begin timing capture
    start_capture_time: float = time.time()
    last_gain_change: float = time.time()  

    # Capture duration (seconds) of frames
    frame_num: int = 0
    while(True):
        # Capture the current time
        current_time: float = time.time()
        
        # If reached desired duration, stop recording
        if((current_time - start_capture_time) >= duration):
            break  

        # Capture the frame and splice only the odd cols (even cols have junk content)
        frame: np.array = cam.capture_array('raw')[:, 1::2]

        # Store the frame + settings into the allocated memory buffers
        frame_buffer[frame_num % CAM_FPS] = frame
        settings_buffer[frame_num % CAM_FPS] = (current_gain, current_exposure) 

        # Change gain every N ms
        if((current_time - last_gain_change) > gain_change_interval):
            # Take the mean intensity of the frame
            mean_intensity = np.mean(frame, axis=(0,1))
            
            # Feed the settings into the the AGC 
            ret = AGC(mean_intensity, current_gain, current_exposure, 0.95, AGC_lib)

            # Retrieve and set the new gain and exposure from our custom AGC
            #new_gain, new_exposure = ret['adjusted_gain'], int(ret['adjusted_exposure'])
            new_gain, new_exposure = 2, 4839
            
            cam.set_controls({'AnalogueGain': new_gain, 'ExposureTime': new_exposure}) 
            
            # Update the current_gain and current_exposure, 
            # wait for next gain change time
            last_gain_change = current_time
            current_gain, current_exposure = new_gain, new_exposure

        # Record the next frame number
        frame_num += 1 

        # If we have now captured one second worth of frames, send the frame buffer 
        # to be written 
        if(frame_num % CAM_FPS == 0):
            #write_queue.put((frame_buffer, frame_num, settings_buffer, frame_timings_buffer))
            write_queue.put((frame_buffer, frame_num, settings_buffer))

    # Record timing of end of capture 
    end_capture_time: float = time.time()
    
    # Signal the end of the write queue
    write_queue.put(None) 
    
    # Calculate the approximate FPS the frames were taken at 
    # (approximate due to time taken for other computation)
    observed_fps: float = (frame_num)/(end_capture_time-start_capture_time)
    print(f'World Camera captured {frame_num} at ~{observed_fps} fps')
    
    # Stop recording and close the picam object 
    cam.close() 
    
"""View a preview view of what the camera currently sees from the main stream"""
def preview_capture():
    from picamera2 import Picamera2, Preview
    
    # Initialize the camera with the settings we have prescribed
    cam: Picamera2 = initialize_camera()

    # Start a preview
    cam.start_preview(Preview.QTGL)
    cam.start()

    # Pause while we are viewing the preview
    print('Press q to cancel preview')
    while(input().lower().strip() != 'q'):
        time.sleep(1)

    # Stop the preview
    cam.stop()
    cam.stop_preview()

    # Close the camera
    cam.close()

"""Connect to the camera and initialize a control object"""
def initialize_camera(initial_gain: float=1, initial_exposure: int=100) -> object:
    from picamera2 import Picamera2

    # Initialize camera 
    cam: Picamera2 = Picamera2()
    
    # Select the mode to put the sensor in
    # (ie, mode for high fps/low res, more pixel HDR etc)
    sensor_mode: dict = cam.sensor_modes[4] # 4		
    
    # Set the mode
    cam.configure(cam.create_video_configuration(sensor={'output_size':sensor_mode['size'], 'bit_depth':sensor_mode['bit_depth']}, 
                                                 main={'size':sensor_mode['size']}, 
                                                 raw=sensor_mode,
                                                 queue=True))
                                                 #buffer_count=150))
  
    # Ensure the frame rate; This is calculated by
    # FPS = 1,000,000 / FrameDurationLimits 
    # e.g. 206.65 = 1000000/FDL => FDL = 1000000/206.65
    # 200 = 
    frame_duration_limit = int(np.ceil(1000000/CAM_FPS))
    cam.video_configuration.controls['NoiseReductionMode'] = 0
    cam.video_configuration.controls['FrameDurationLimits'] = (frame_duration_limit,frame_duration_limit) # for lower,upper bound equal
    
    # Set runtime camera information, such as auto-gain
    # auto exposure, white point balance, etc
    # Note, AeEnable changes both AEC and AGC		
    cam.video_configuration.controls['AwbEnable'] = 0
    cam.video_configuration.controls['AeEnable'] = 0  

    #cam.video_configuration.controls['AnalogueGain'] = 2
    #cam.video_configuration.controls['ExposureTime'] = initial_exposure


    # HARDCODED FOR THE TEST
    cam.video_configuration.controls['AnalogueGain'] = 2
    cam.video_configuration.controls['ExposureTime'] = 4839
    
    return cam
