import os 
import time 
import cv2
import numpy as np
import pickle
import queue
import threading
import pandas as pd
from natsort import natsorted
import uvc
import matplotlib.pyplot as plt

CAM_FPS: int = 30

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
def write_frame(write_queue: queue.Queue, filename: str):
    # Create output directory for frames   
    if(not os.path.exists(filename)):
        os.mkdir(filename)

    while(True):  
        # Retrieve a tuple of (frame, frame_num) from the queue
        ret: tuple = write_queue.get()

        # If we didn't receive a frame, we are at the end 
        # of the video, finish writing
        if(ret is None):
            print('BREAKING WRITING')
            break
        
        # Retrieve the information out of the ret tuple
        frame_buffer, frame_num = ret
        
        #print(f'writing {frame_num}')
        print(f"Pupil Queue size: {write_queue.qsize()}")

        # Write the frame
        save_path: str = os.path.join(filename, f'{frame_num}.npy')
        np.save(save_path, frame_buffer)


"""Record live from the camera with no specified duration"""
def record_live(duration: float, write_queue: queue.Queue, filename: str, 
                initial_gain: float, initial_exposure: int,
                stop_flag: threading.Event):
    # Connect to and set up camera
    print(f"Initializing camera")
    cam: uvc.Capture = initialize_camera()
    
    # Begin Recording and capture initial metadata 
    current_gain, current_exposure = 0, 0   

    # Initialize buffers to store the frame/settigns data for 1 second's 
    # worth of video
    frame_buffer: np.array = np.zeros((CAM_FPS, 192, 192), dtype=np.uint8)

    # Capture indefinite frames
    frame_num = 0
    while(not stop_flag.is_set()):
        # Capture the current time
        current_time: float = time.time()
        
        # Capture the frame
        frame_obj: uvc_bindings.MJPEGFrame = cam.get_frame_robust()

        # Store the grayscale frame + settings into the allocated memory buffers
        frame_buffer[frame_num % CAM_FPS] = frame_obj.gray

        # If we have finished capturing one second of video, 
        # send the buffer to be written
        if(frame_num % CAM_FPS == 0):
            write_queue.put((frame_buffer, frame_num))

        # Record the next frame number
        frame_num += 1 

    # Signal the end of the write queue
    write_queue.put(None)

    # Close the camera
    cam.close()

"""Record a viceo from the Raspberry Pi camera"""
def record_video(duration: float, write_queue: queue.Queue, filename: str, 
                 initial_gain: float, initial_exposure: int,
                 stop_flag: threading.Event): 

    # Connect to and set up camera
    print(f"Initializing camera")
    cam: uvc.Capture = initialize_camera()
    
    # Retrieve the initial gain and exposure values
    current_gain, current_exposure = 0, 0   

    # Initialize buffers to store the frame/settigns data for 1 second's 
    # worth of video
    frame_buffer: np.array = np.zeros((CAM_FPS, 192, 192), dtype=np.uint8)

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

        # If we have finished capturing one second of video, 
        # send the buffer to be written
        if(frame_num % CAM_FPS == 0):
            write_queue.put((frame_buffer, frame_num))

        # Record the next frame number
        frame_num += 1 
            
    # Record timing of end of capture 
    end_capture_time: float = time.time()
    
    # Signal the end of the write queue
    write_queue.put(None) 
    
    # Calculate the approximate FPS the frames were taken at 
    # (approximate due to time taken for other computation)
    observed_fps: float = frame_num/(end_capture_time-start_capture_time)
    print(f'I captured {frame_num} at {observed_fps} fps')
    
    # Stop recording and close the camera object 
    cam.close()
    
    print('Finishing recording')

# TODO: This does not yet work because no display method seems to work on RPI
"""Preview the camera feed"""
def preview_capture():
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
def initialize_camera() -> uvc.Capture:
    # Retrieve the camera device
    device, *_ = uvc.device_list()

    # Open a connection to the camera
    cam: uvc.Capture = uvc.Capture(device["uid"])

    # Set the camera to be 192x192 @ 60 FPS
    cam.frame_mode = cam.available_modes[0]

    # Retrieve the controls dict
    controls_dict: dict = {c.display_name: c for c in cam.controls}

    # Configure the 200hz IR cameras 
    controls_dict['Auto Exposure Mode'].value = 1
    controls_dict["Auto Focus"].value = 1
    

    #print(controls_dict)
    #print(dir(cam))

    return cam 
    

def main():
    preview_capture()


if(__name__ == '__main__'):
    main()
