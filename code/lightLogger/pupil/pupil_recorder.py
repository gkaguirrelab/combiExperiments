import os 
import time 
import cv2
import numpy as np
import psutil
import pickle
import queue
import threading
import pandas as pd
from natsort import natsorted
import matplotlib.pyplot as plt
import signal
import traceback
import setproctitle
import sys
import uvc
import multiprocessing as mp

# The FPS we have locked the camera to
CAM_FPS: int = 120

# The origial dimensions of the camera before downsampling 
CAM_IMG_DIMS: np.ndarray = np.array((192, 192))

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
        print(f'Pupil unpacking buffer: {i+1}/{len(frame_buffer_files)}')

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
    return pd.read_csv(path, header=None, names=['Frame', 'Gain', 'Exposure'])

"""Read in a video from a file to an 8-bit unsigned np.array"""
def vid_array_from_npy_folder(path: str) -> np.array:
    frames = [np.load(os.path.join(path, frame)) 
              for frame in natsorted(os.listdir(path)) 
              if '.pkl' not in frame and '.txt' not in frame] 
    
    return np.array(frames, dtype=np.uint8)

"""Construct a video from a series of frames, output to output_path"""
def reconstruct_video(video_frames: np.array, output_path: str):
    # Define the information about the video to use for writing
    fps = CAM_FPS  
    height, width = video_frames[0].shape[:2]

    # Initialize VideoWriter object to write frames to
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(output_path, fourcc, fps, (width, height), 
                          isColor=len(video_frames.shape) > 3)

    # Write all of the frames to the video
    for i in range(video_frames.shape[0]):
        out.write(video_frames[i])

    # Release the VideoWriter object
    out.release()


"""Write a frame and its info in the write queue to disk 
in the output_path directory and to the settings file"""
def write_frame(write_queue: queue.Queue, filename: str, generate_settingsfile: bool=True):
    # Ensure the output directory exists (if we are not running via signalcommunication)
    if(not os.path.exists(filename) and generate_settingsfile):
        os.makedirs(filename)

    # While true, wait to be sent frames to write
    while(True):  
        # Retrieve a tuple of (frame, frame_num) from the queue
        ret: tuple = write_queue.get()

        # If we didn't receive a frame, we are at the end 
        # of the video, finish writing
        if(ret is None):
            break
        
        # Retrieve the information out of the ret tuple
        frame_buffer, frame_num = ret[0:2]

        # If the length is greater than 2, we have explictly passed 
        # a settings file and a filename
        if(len(ret) > 2):
            filename, settings_file = ret[2:4]

        # Quickly check and ensure the output directory exists 
        # it always should, but I had an error where it didn't. 
        # must have been timing related
        if(not os.path.exists(filename)): os.mkdir(filename)

        #print(f'writing {frame_num}')
        print(f"Pupil Queue size: {write_queue.qsize()}")

        # Write the frame
        save_path: str = os.path.join(filename, f'{frame_num}.npy')

        np.save(save_path, frame_buffer)


"""Record live from the camera with no specified duration"""
def record_live(duration: float, write_queue: queue.Queue, 
                filename: str, stop_flag: threading.Event,
                is_subprocess: bool, parent_pid: int,
                go_flag: threading.Event):
    # Import the necessary library (causes conflict on other machines, so just do it locally)
    import uvc

    # Connect to and set up camera
    print(f"Initializing camera")
    cam: uvc.Capture = initialize_camera()
    
    # Begin Recording and capture initial metadata 
    current_gain, current_exposure = 0, 0   

    # Initialize buffers to store the frame/settigns data for 1 second's 
    # worth of video
    frame_buffer: np.array = np.zeros((CAM_FPS, 400, 400), dtype=np.uint8)

    # Capture indefinite frames
    frame_num = 0
    while(not stop_flag.is_set()):
        # Capture the current time
        current_time: float = time.time()
        
        # Capture the frame
        frame_obj: uvc_bindings.MJPEGFrame = cam.get_frame_robust()

        # Store the grayscale frame + settings into the allocated memory buffers
        frame_buffer[frame_num % CAM_FPS] = frame_obj.gray
        
        # Record the next frame number
        frame_num += 1 

        # If we have finished capturing one second of video, 
        # send the buffer to be written
        if(frame_num % CAM_FPS == 0):
            write_queue.put((frame_buffer, frame_num))

    # Signal the end of the write queue
    write_queue.put(None)

    # Close the camera
    cam.close()

"""A helper function that contains the meat of capturing 
   a video of a set length, for use when communicating 
   via signals"""
def capture_helper(cam: object, duration: float, write_queue: queue.Queue,
                  frame_buffer: np.ndarray,
                  filename: str, settings_file: object, 
                  burst_num: int):
    print('Pupil Cam: Beginning capture')

    # Begin timing capture
    start_capture_time: float = time.time() 
    
    # Capture duration (seconds) of frames
    frame_num: int = 0
    while(True):
        # Capture the current time
        current_time: float = time.time()

        # If reached desired duration, stop recording
        if((current_time - start_capture_time) >= duration):
            break  

        # Capture the frame
        frame_obj: uvc_bindings.MJPEGFrame = cam.get_frame_robust()

        # Store the grayscale frame + settings into the allocated memory buffers
        frame_buffer[frame_num % CAM_FPS] = frame_obj.gray

        # Record the next frame number
        frame_num += 1 

        # If we have finished capturing one second of video, 
        # send the buffer to be written
        if(frame_num % CAM_FPS == 0):
            write_queue.put((frame_buffer, frame_num, filename, settings_file))
    
    # Record timing of end of capture 
    end_capture_time: float = time.time()
    
    # Calculate the approximate FPS the frames were taken at 
    # (approximate due to time taken for other computation)
    observed_fps: float = (frame_num)/(end_capture_time-start_capture_time)
    print(f'Pupil cam: captured {frame_num} at ~{observed_fps} fps')

"""Record a video from the Pupil camera of a set duration
   via signal communication with a master process (only inits cams once)"""
def record_video_signalcom(duration: float, write_queue: queue.Queue, 
                           filename: str, stop_flag: threading.Event,
                           is_subprocess: bool, parent_pid: int,
                           go_flag: threading.Event,
                           burst_num: int=0): 
    # Import the necessary library (causes conflict on other machines, so just do it locally)
    import uvc

    # Retrieve the name of the controller this recorder is operating out of
    controller_name: str = setproctitle.getproctitle()
    
    # Define the path to the controller READY files
    READY_file_dir: str = "/home/rpiControl/combiExperiments/code/lightLogger/raspberry_pi_firmware/READY_files"
    GO_file_dir: str = "/home/rpiControl/combiExperiments/code/lightLogger/raspberry_pi_firmware/GO_files"
    STOP_file_dir: str = "/home/rpiControl/combiExperiments/code/lightLogger/raspberry_pi_firmware/STOP_files"

    # Define the name of this controller's READY file 
    READY_file_name: str = os.path.join(READY_file_dir, f"{controller_name}|READY")

    # Connect to and set up camera
    try:
        print(f"Initializing pupil camera")
        cam: uvc.Capture = initialize_camera()
    except Exception as e:
        # Print the traceback to stderror for this exception
        traceback.print_exc()
        print(e)
        print('Pupil cam failed to initialize')
        sys.exit(1)
    
    # Retrieve the initial gain and exposure values
    current_gain, current_exposure = 0, 0   

    # Initialize buffers to store the frame/settigns data for 1 second's 
    # worth of video
    frame_buffer: np.array = np.zeros((CAM_FPS, 400, 400), dtype=np.uint8)

    # If we were run as a subprocess, send a message to the parent 
    # process that we are ready to go
    try:
        print(f'Pupil Cam: Initialized. Sending ready signal to parent: {parent_pid}')
        
        # Add a READY file for this controller
        with open(READY_file_name, 'w') as f: pass

        # While we have not receieved the GO signal, wait 
        start_wait: float = time.time()
        last_read: float = time.time()
        while(not go_flag.is_set()):
            # Set the GO flag if we have received a GO signal
            if(len(os.listdir(GO_file_dir)) > 0): go_flag.set()

            # Capture the current time
            current_wait: float = time.time()

            # If the parent process is no longer existent, something has gone wrong
            # and we should quit 
            if(not psutil.pid_exists(parent_pid)):
                raise Exception('ERROR: Parent process was killed')
            
            if((current_wait - last_read) >= 2):
                print('Pupil Cam: Waiting for GO signal...')
                last_read = current_wait
    
    # Catch if there was an error in some part of the pipeline and we did not receive 
    # a GO signal (parent process was killed)
    except Exception as e:
        # Close the camera on error 
        cam.close()
        
        # Print the traceback to stderr for this exception 
        traceback.print_exc()
        print(e)
        sys.exit(1)

    # Define the starting burst number
    # and the thus the initial filename
    # and settings file
    filename : str = filename.replace('burstX', f"burst{burst_num}") 
    settings_file: object = None # None because we are currently not tracking any settings

    # Once the GO signal has been received, begin capturing chunks until we 
    # receive a stop signal
    while(True):     
        # Use the milliseconds of time gaps between GO signals to generate files and hopefully not add 
        # any delay in the start of a burst capture
        # Akin to racing the beam on ATARI 2600, pretty cool! 
        # Check to see if the STOP file exists, if it does, we end recording
        if(len(os.listdir(STOP_file_dir)) > 0): break 

        # Set the GO flag if we have received a GO signal
        if(len(os.listdir(GO_file_dir)) > 0): go_flag.set()

        # Generate the directory for this burst if it does not already exist
        if(not os.path.exists(filename)): os.mkdir(filename)
    
        # While we have the GO signal, record a burst
        while(go_flag.is_set()):
            # Capture duration worth of frames
            capture_helper(cam, duration, write_queue,
                           frame_buffer,
                           filename, settings_file,
                           burst_num)

            # Stop recording until we receive the GO signal again 
            go_flag.clear()
            
            # Try except here because multiple controllers could be trying to remove this file at once 
            # so it could be deleted by the time another goes to delete it
            try:
                for file in os.listdir(GO_file_dir): os.remove(os.path.join(GO_file_dir, file))
            except:
                pass 


            # Report to the parent process we are ready to go for the next burst 
            assert(not os.path.exists(READY_file_name))
            with open(READY_file_name, 'w') as f: pass
            print(f'Pupil: Finished burst: {burst_num+1} | Sending READY signal for parent: {parent_pid}!')
        
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

    # Remove any left over READY file if it is empty 
    if(os.path.exists(READY_file_name)): os.remove(READY_file_name)

    print(f'Pupil cam: Finishing recording')

"""Record a video from the Pupil camera of a set duration. Can be as 
   a subprocess or not. If a subprocess, will need to be reinitialized 
   for every capture."""
def record_video(duration: float, write_queue: queue.Queue, 
                 filename: str, stop_flag: threading.Event,
                 is_subprocess: bool, parent_pid: int,
                 go_flag: threading.Event): 
    # Import the necessary library (causes conflict on other machines, so just do it locally)
    import uvc

    # Connect to and set up camera
    try:
        print(f"Initializing pupil camera")
        cam: uvc.Capture = initialize_camera()
    except Exception as e:
        # Print the traceback to stderror for this exception
        traceback.print_exc()
        print(e)
        print('Pupil cam failed to initialize')
        sys.exit(1)
    
    # Retrieve the initial gain and exposure values
    current_gain, current_exposure = 0, 0   

    # Initialize buffers to store the frame/settigns data for 1 second's 
    # worth of video
    frame_buffer: np.array = np.zeros((CAM_FPS, 400, 400), dtype=np.uint8)

    # If we were run as a subprocess, send a message to the parent 
    # process that we are ready to go
    try:
        if(is_subprocess): 
            print('Pupil Cam: Initialized. Sending ready signal...')
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
                
                if((current_wait - last_read) >= 2):
                    print('Pupil Cam: Waiting for GO signal...')
                    last_read = current_wait
    # Catch if there was an error in some part of the pipeline and we did not receive 
    # a go signal in the appropriate amount of time
    except Exception as e:
        # Close the camera on error 
        cam.close()
        
        # Print the traceback to stderr for this exception 
        traceback.print_exc()
        print(e)
        sys.exit(1)

    # Once the go signal has been received, begin capturing
    print('Pupil Cam: Beginning capture')

    # Begin timing capture
    start_capture_time = time.time() 
    
    # Capture duration (seconds) of frames
    frame_num: int = 0
    while(True):
        # Capture the current time
        current_time: float = time.time()

        # If reached desired duration, stop recording
        if((current_time - start_capture_time) >= duration):
            break  

        # Capture the frame
        frame_obj: uvc_bindings.MJPEGFrame = cam.get_frame_robust()

        # Store the grayscale frame + settings into the allocated memory buffers
        frame_buffer[frame_num % CAM_FPS] = frame_obj.gray

        # Record the next frame number
        frame_num += 1 

        # If we have finished capturing one second of video, 
        # send the buffer to be written
        if(frame_num % CAM_FPS == 0):
            write_queue.put((frame_buffer, frame_num))
            
    # Record timing of end of capture 
    end_capture_time: float = time.time()
    
    # Signal the end of the write queue
    write_queue.put(None) 
    
    # Calculate the approximate FPS the frames were taken at 
    # (approximate due to time taken for other computation)
    observed_fps: float = frame_num/(end_capture_time-start_capture_time)
    print(f'Pupil cam captured {frame_num} at {observed_fps} fps')
    
    # Stop recording and close the camera object 
    cam.close()
    
    print('Pupil cam: Finishing recording')


def lean_capture_helper(cam: object, duration: int, 
                       frame_buffer: np.ndarray, 
                       write_queue: mp.Queue):

    # Begin timing capture
    start_time = time.time() 
    
    # Define indices to place frames/settings into the 
    # provided buffers
    frame_num: int = 0

    # Capture duration of frames
    while(True):
        # Capture the current time
        current_time: float = time.time()

        # Calculate the elapsed time from the start 
        elapsed_time: float = current_time - start_time

        # If reached desired duration, stop recording
        if(elapsed_time >= duration):
            break  

        # Capture the frame
        frame_obj: uvc_bindings.MJPEGFrame = cam.get_frame_robust()
        #frame = np.empty((400,400), dtype=np.uint8)

        # Store the grayscale frame + settings into the allocated memory buffers
        frame_buffer[frame_num] = frame_obj.gray

        # Record the next frame number
        frame_num += 1 
            
    # Record timing of end of capture 
    end_time: float = time.time()

    # Calculate the approximate FPS the frames were taken at 
    # (approximate due to time taken for other computation)
    observed_fps: float = frame_num/(end_time-start_time)
    print(f'Pupil cam captured {frame_num} at {observed_fps} fps')

    # Append the chunk to the write queue 
    write_queue.put(('P', frame_buffer, frame_num, observed_fps))
    
    # Signal the end of the write queue
    write_queue.put(('P', None)) 


def lean_capture(write_queue: mp.Queue, receive_queue: mp.Queue, 
                 duration: int):
    # Initialize the camera
    cam: uvc.Capture = initialize_camera()
    #cam = None

    # Define a buffer of duration * second worth of frames to capture and 
    # their respective settings. Allocate an additioanl second worth of frames 
    # in case we capture more than the target FPS (like 120.1) for instance
    frame_buffer: np.array = np.empty(((duration + 1) * CAM_FPS, *CAM_IMG_DIMS), dtype=np.uint8)
    #dummy_buffer: np.array = np.empty(((duration + 1) * CAM_FPS, *(CAM_IMG_DIMS//2)), dtype=np.uint8)

    print('Pupil Cam | Initialized')

    # Remain initialized and ready to capture until we have received a STOP
    STOP: bool = False
    while(STOP is False):
        print('Pupil Cam | Awaiting GO')
        # Retrieve whether we should go or not from 
        # the main process 
        GO: bool | int = receive_queue.get()

        # If GO received special flag, we end completely
        if(GO is False):
            print('Pupil Cam | Received STOP')
            STOP = True
            break    

        # Otherwise, we capture a burst of duration long 
        while(GO is True):
            print(f'Pupil Cam | Capturing chunk')
            # Capture a burst of frames
            lean_capture_helper(cam, duration,
                                frame_buffer, 
                                write_queue)

            # Set GO back to False 
            GO = False

    # Append to the main process queue and let it know we are really done 
    write_queue.put(('P', False))

    # Close the camera
    print(f'Pupil Cam | Closing')
    cam.close()

# TODO: This does not yet work because no display method seems to work on RPI
"""Preview the camera feed"""
def preview_capture():
    # Import the necessary library (causes conflict on other machines, so just do it locally)
    import uvc
    
    # Open a connection to the camera
    cam: uvc.Capture = initialize_camera()

    # Display the image that was captured
    try:
        while(True):
            # Capture a frame from the camera
            frame_obj: uvc_bindings.MJPEGFrame = cam.get_frame_robust()

            cv2.imwrite('test.jpg', frame_obj.gray)

            print(f'Mean Count: {frame_obj.gray.mean()}')

    except:
        pass

    # Close the connection to the camera 
    cam.close()

"""Iniitalize the pupil camera"""        
def initialize_camera() -> object:
    # Import the necessary library (causes conflict on other machines, so just do it locally)
    import uvc

    # Retrieve the camera device
    device, *_ = uvc.device_list()

    # Open a connection to the camera
    cam: uvc.Capture = uvc.Capture(device["uid"])

    # Set the camera to be 192x192 @ 120 FPS
    cam.frame_mode = cam.available_modes[3]

    # Retrieve the controls dict
    controls_dict: dict = {c.display_name: c for c in cam.controls}

    # Configure the 200hz IR cameras 
    controls_dict['Auto Exposure Mode'].value = 1
    controls_dict["Auto Focus"].value = 1

    return cam 
    

def main():
    preview_capture()


if(__name__ == '__main__'):
    main()
