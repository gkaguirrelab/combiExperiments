import os 
import time 
import cv2
import numpy as np
import pickle
import queue
import threading
import pandas as pd
from natsort import natsorted

CAM_FPS: int = 30

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
        
        # Retrieve the information out of the ret tuple
        frame, frame_num, current_exposure, current_gain = ret
        
        #print(f'writing {frame_num}')
        print(f"Pupil Queue size: {write_queue.qsize()}")

        # Write the frame
        save_path: str = os.path.join(filename, f'{frame_num}.npy')
        np.save(save_path, frame)

        # Write the frame info 
        settings_file.write(f'{frame_num},{current_gain},{current_exposure}\n')

    # Close the settings file
    settings_file.close()


"""Record live from the camera with no specified duration"""
def record_live(duration: float, write_queue: queue.Queue, filename: str, 
                initial_gain: float, initial_exposure: int,
                stop_flag: threading.Event):
    # Connect to and set up camera
    print(f"Initializing camera")
    cam: cv2.VideoCapture = initialize_camera()
    gain_change_interval: float = 0.250 # the time between AGC adjustments 
    
    # Begin Recording and capture initial metadata 
    current_gain, current_exposure = 0, 0      

    # Initialize the last time we changed the gain as the current time
    last_gain_change: float = time.time()  

    # Capture indefinite frames
    frame_num = 1 
    while(not stop_flag.is_set()):
        # Capture the frame
        ret, frame = cam.read()

        # Ensure a frame was read properly
        if(not ret):
            print(f"ERROR: Could not read frame")
            break
        
        # Capture the current time
        current_time: float = time.time()

        # Append the frame and its relevant information 
        # to the storage containers
        write_queue.put((frame, frame_num, current_exposure, current_gain))
        
        # Change gain every N ms
        if((current_time - last_gain_change)  > gain_change_interval):
            # Take the mean intensity of the frame
            #mean_intensity = np.mean(frame, axis=(0,1))

            # Retrieve and set the new gain and exposure from our custom AGC
            new_gain, new_exposure = 0, 0 
            
            # Update the current_gain and current_exposure, 
            # wait for next gain change time
            last_gain_change = current_time
            current_gain, current_exposure = new_gain, new_exposure

        # Record the next frame number
        frame_num += 1 

    # Signal the end of the write queue
    write_queue.put(None)

    # Close the camera
    cam.release() 

"""Record a viceo from the Raspberry Pi camera"""
def record_video(duration: float, write_queue: queue.Queue, filename: str, 
                 initial_gain: float, initial_exposure: int,
                 stop_flag: threading.Event): 

    # Connect to and set up camera
    print(f"Initializing camera")
    cam: cv2.VideoCapture = initialize_camera()
    gain_change_interval: float = 0.250 # the time between AGC adjustments 
    
    # Retrieve the initial gain and exposure values
    current_gain, current_exposure = 0, 0   
    
    # Create containers to store the gain and exposure 
    # of every frame
    gain_history, exposure_history = [], [] 

    # Begin timing capture
    start_capture_time: float = time.time()
    last_gain_change: float = time.time()  
    
    # Capture duration (seconds) of frames
    frame_num: int = 1 
    while(True):
        # Capture the frame
        ret, frame = cam.read()

        # Ensure a frame was properly read 
        if(not ret):
            print(f"ERROR: Could not read frame")
            break

        # Capture the current time
        current_time: float = time.time()

        # Append the frame and its relevant information 
        # to the storage containers
        write_queue.put((frame, frame_num, current_gain, current_exposure))
        gain_history.append(current_gain)
        exposure_history.append(current_exposure)
        
        # Change gain every N ms
        if((current_time - last_gain_change)  > gain_change_interval):
            # Take the mean intensity of the frame
            mean_intensity = np.mean(frame, axis=(0,1))

            # Retrieve and set the new gain and exposure from our custom AGC
            new_gain, new_exposure = 0, 0
            
            # Update the current_gain and current_exposure, 
            # wait for next gain change time
            last_gain_change = current_time
            current_gain, current_exposure = new_gain, new_exposure
        
        # If reached desired duration, stop recording
        if((current_time - start_capture_time) >= duration):
            break  

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
    cam.release()
    
    print('Finishing recording')

"""Preview the camera feed"""
def preview_capture():
    # Open a connection to the camera
    cam: cv2.VideoCapture = initialize_camera()

    # Capture and display frames
    while(True):
        # Capture the frame
        ret, frame = cam.read()

        # Ensure a frame was properly read 
        if not ret:
            print("ERROR: Could not read frame")
            break
        
        # Display the frame
        cv2.imshow('Camera Feed', frame)

        # Break the loop if 'q' is pressed
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    # Release the camera and close all windows
    cam.release()
    cv2.destroyAllWindows()

"""Iniitalize the pupil camera"""        
def initialize_camera() -> cv2.VideoCapture:
    # Open a connection to the camera at index 0
    cam: cv2.VideoCapture = cv2.VideoCapture(8, cv2.CAP_V4L2)

    # Hangs on 8, 9, 24

    # Ensure the camera could be opened
    if(not cam.isOpened()):
        raise Exception("Error: Could not open camera.")

    # Placeholders until we do more research into this
    width: int = 640
    height: int = 480
    fps: int = 30
    initial_exposure_value = cam.get(cv2.CAP_PROP_EXPOSURE)
    initial_gain_value = cam.get(cv2.CAP_PROP_GAIN)
    
    # Set the properties of the camera image
    cam.set(cv2.CAP_PROP_FRAME_WIDTH, width)
    cam.set(cv2.CAP_PROP_FRAME_HEIGHT, height)

    # Set the properties of the camera
    cam.set(cv2.CAP_PROP_AUTO_EXPOSURE, 0.75)
    cam.set(cv2.CAP_PROP_FPS, fps)
    cam.set(cv2.CAP_PROP_GAIN, initial_gain_value)
    cam.set(cv2.CAP_PROP_EXPOSURE, initial_exposure_value)

    return cam
