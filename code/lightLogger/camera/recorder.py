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

"""Import the custom AGC library"""
agc_lib_path = os.path.join(os.path.dirname(__file__), 'AGC_lib')
sys.path.append(os.path.abspath(agc_lib_path))
from PyAGC import import_AGC_lib, AGC

AGC_lib = import_AGC_lib()

"""Import the custom Downsampling library"""
downsample_lib_path = os.path.join(os.path.dirname(__file__), 'downsample_lib')
sys.path.append(os.path.abspath(downsample_lib_path))
from PyDownsample import import_downsample_lib, downsample

# Import the CPP downsample lib (with types, etc)
downsample_lib = import_downsample_lib()

# The FPS we have locked the camera to
CAM_FPS: float = 120

"""Write a frame and its info in the write queue to disk 
in the output_path directory and to the settings file"""
def write_frame(write_queue: queue.Queue, filename: str):
    # Create output directory for frames   
    if(not os.path.exists(filename)):
        os.mkdir(filename)

    # Initialize a settings file for per-frame settings to be written to.
    settings_file = open(f'{filename}_settingsHistory.csv', 'a')

    while(True):  
        # Retrieve a tuple of (frame, frame_num) from the queue
        ret: tuple = write_queue.get()

        # If we didn't receive a frame, we are at the end 
        # of the video, finish writing
        if(ret is None):
            print('BREAKING WRITING')
            break
        
        # Extract frame and its metadata
        frame_buffer, frame_num, settings_buffer = ret

        # Print out the state of the write queue
        print(f'Camera queue size: {write_queue.qsize()}')

        # Write the frame
        save_path: str = os.path.join(filename, f'{frame_num}.npy')
        np.save(save_path, frame_buffer)

        # Write the frame info to the existing csv file
        np.savetxt(settings_file, settings_buffer, delimiter=',', fmt='%d')

    # Close the settings file
    settings_file.close()

    print('finishing writing')

"""Unpack chunks of n captured frames. This is used 
   to reformat the memory-limitation required capture 
   buffer format into the single frame files the codebase 
   is built on at the end of a capture."""
def unpack_capture_chunks(path_to_frames: str):
    # Declare an accumulator variable to hold the real frame number 
    # of each frame when we resave it 
    frame_num: int = 0

    # Iterate over the frame buffer files
    for frame_buffer_file in natsorted(os.listdir(path_to_frames)):
        # Load in this buffer 
        frame_buffer: np.ndarray = np.load(os.path.join(path_to_frames, frame_buffer_file))

        # Iterate over the frames in the buffer 
        for frame in frame_buffer:
            # Construct the new path to save this file (all buffer files will be overwritten by these)
            save_path: str = os.path.join(path_to_frames, f'{frame_num}.npy')

            # Save the frame
            np.save(save_path, frame)

            # Increment the frame number
            frame_num += 1 


"""Parse the setting file for a video as a data frame"""
def parse_settings_file(path: str) -> pd.DataFrame:
    return pd.read_csv(path, header=None, names=['frame_num', 'gain_history', 'exposure_history'])

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

"""Record live from the camera with no specified duration"""
def record_live(duration: float, write_queue: queue.Queue, filename: str, 
                initial_gain: float, initial_exposure: int,
                stop_flag: threading.Event):
    from picamera2 import Picamera2

    # Connect to and set up camera
    print(f"Initializing camera")
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
    frame_buffer: np.array = np.zeros((CAM_FPS, 480, 640), dtype=np.uint8)
    settings_buffer: np.array = np.zeros((CAM_FPS, 2), dtype=np.float16) 

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
        settings_buffer[frame_num % CAM_FPS] = [current_gain, current_exposure]
   
        # Change gain every N ms
        if((current_time - last_gain_change) > gain_change_interval):
            # Take the mean intensity of the frame
            mean_intensity = np.mean(frame, axis=(0,1))
            
            # Feed the settings into the the AGC 
            ret = AGC(mean_intensity, current_gain, current_exposure, 0.95, AGC_lib)

            # Retrieve and set the new gain and exposure from our custom AGC
            new_gain, new_exposure = ret['adjusted_gain'], int(ret['adjusted_exposure'])
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
            write_queue.put((frame_buffer, frame_num, settings_buffer))

    # Signal the end of the write queue
    write_queue.put(None) 

    # Close the camera
    cam.close()

"""Record a viceo from the Raspberry Pi camera"""
def record_video(duration: float, write_queue: queue.Queue, filename: str, 
                 initial_gain: float, initial_exposure: int,
                 stop_flag: threading.Event): 
    from picamera2 import Picamera2

    # Connect to and set up camera
    print(f"Initializing camera")
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
    frame_buffer: np.array = np.zeros((CAM_FPS, 480, 640), dtype=np.uint8)
    settings_buffer: np.array = np.zeros((CAM_FPS, 2), dtype=np.float16)   

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
        settings_buffer[frame_num % CAM_FPS] = [current_gain, current_exposure]
   
        # Change gain every N ms
        if((current_time - last_gain_change) > gain_change_interval):
            # Take the mean intensity of the frame
            mean_intensity = np.mean(frame, axis=(0,1))
            
            # Feed the settings into the the AGC 
            ret = AGC(mean_intensity, current_gain, current_exposure, 0.95, AGC_lib)

            # Retrieve and set the new gain and exposure from our custom AGC
            new_gain, new_exposure = ret['adjusted_gain'], int(ret['adjusted_exposure'])
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
            write_queue.put((frame_buffer, frame_num, settings_buffer))

    # Record timing of end of capture 
    end_capture_time: float = time.time()
    
    # Signal the end of the write queue
    write_queue.put(None) 
    
    # Calculate the approximate FPS the frames were taken at 
    # (approximate due to time taken for other computation)
    observed_fps: float = (frame_num)/(end_capture_time-start_capture_time)
    print(f'I captured {frame_num} at {observed_fps} fps')
    
    # Stop recording and close the picam object 
    cam.close() 
    
    print('Finishing recording')
    
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
    cam.configure(cam.create_video_configuration(sensor={'output_size':sensor_mode['size'], 'bit_depth':sensor_mode['bit_depth']}, main={'size':sensor_mode['size']}, raw=sensor_mode))

    # Ensure the frame rate; This is calculated by
    # FPS = 1,000,000 / FrameDurationLimits 
    # e.g. 206.65 = 1000000/FDL => FDL = 1000000/206.65
    # 200 = 
    frame_duration_limit = int(np.ceil(1000000/CAM_FPS))
    cam.video_configuration.controls['NoiseReductionMode'] = 0
    cam.video_configuration.controls['FrameDurationLimits'] = (frame_duration_limit,frame_duration_limit) # *2 for lower,upper bound equal
    
    # Set runtime camera information, such as auto-gain
    # auto exposure, white point balance, etc
    # Note, AeEnable changes both AEC and AGC		
    cam.video_configuration.controls['AwbEnable'] = 0
    cam.video_configuration.controls['AeEnable'] = 0  
    cam.video_configuration.controls['AnalogueGain'] = initial_gain
    cam.video_configuration.controls['ExposureTime'] = initial_exposure
    
    return cam
