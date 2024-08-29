import time
import os 
import cv2 
import queue
from natsort import natsorted
import numpy as np
import sys
import pickle
import threading

"""Import the custom AGC library"""
agc_lib_path = os.path.join(os.path.dirname(__file__), 'AGC_lib')
sys.path.append(os.path.abspath(agc_lib_path))
from PyAGC import AGC

# The FPS we have locked the camera to
CAM_FPS: float = 200

"""Write a frame and its info in the write queue to disk 
in the output_path directory and to the settings file"""
def write_frame(write_queue: queue.Queue, filename: str):
    # Create output directory for frames   
    if(not os.path.exists(filename)):
        os.mkdir(os.path.basename(filename))

    # Initialize a settings file for per-frame settings to be written to.
    settings_file = open(f'{os.path.basename(filename)}_settingsHistory.txt', 'a')

    while(True):  
        # Retrieve a tuple of (frame, frame_num) from the queue
        ret: tuple = write_queue.get()

        # If we didn't receive a frame, we are at the end 
        # of the video, finish writing
        if(ret is None):
            print('BREAKING WRITING')
            break
        
        # Extract frame and frame_num by name
        frame, frame_num, current_time, current_gain, current_exposure = ret

        # Construct the path to save this frame to
        save_path: str = os.path.join(filename, f"{frame_num}.tiff")
        
        print(f'writing {save_path}')

        # Write the frame
        cv2.imwrite(save_path, frame)

        # Write the frame info 
        settings_file.write(f'{current_time} | {frame_num} | {current_gain} | {current_exposure}')

    # Close the settings file
    settings_file.close()

    print('finishing writing')

"""Read in a video from a file to an 8-bit unsigned np.array"""
def vid_array_from_file(path: str) -> np.array:
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
    from picamera2 import Picamera2, Preview

    # Connect to and set up camera
    print(f"Initializing camera")
    cam: Picamera2 = initialize_camera(initial_gain, initial_exposure)
    gain_change_interval: float = 0.250 # the time between AGC adjustments 
    
    # Begin Recording and capture initial metadata 
    cam.start("video")  
    initial_metadata = cam.capture_metadata()
    current_gain, current_exposure = initial_metadata['AnalogueGain'], initial_metadata['ExposureTime']
    
    # Make absolutely certain Ae and AWB are off 
    # (had to put this here at some point) for it to work 
    cam.set_controls({'AeEnable':0, 'AwbEnable':0})     

    # Initialize the last time we changed the gain as the current time
    last_gain_change = time.time()  

    # Capture indefinite frames
    frame_num = 1 
    while(not stop_flag.is_set()):
        # Capture the frame
        frame = cam.capture_array("raw")

        # Capture the current time
        current_time = time.time()

        # Append the frame and its relevant information 
        # to the storage containers
        write_queue.put((frame, frame_num, current_time, current_exposure, current_gain))
        
        # Change gain every N ms
        if((current_time - last_gain_change)  > gain_change_interval):
            # Take the mean intensity of the frame
            mean_intensity = np.mean(frame, axis=(0,1))
            
            # Feed the settings into the the AGC 
            ret = AGC(mean_intensity, current_gain, current_exposure, 0.95)

            # Retrieve and set the new gain and exposure from our custom AGC
            new_gain, new_exposure = ret['adjusted_gain'], int(ret['adjusted_exposure'])
            cam.set_controls({'AnalogueGain': new_gain, 'ExposureTime': new_exposure}) 
            
            # Update the current_gain and current_exposure, 
            # wait for next gain change time
            last_gain_change = current_time
            current_gain, current_exposure = new_gain, new_exposure

        # Record the next frame number
        frame_num += 1 

    # Signal the end of the write queue
    write_queue.put(None) 

"""Record a viceo from the Raspberry Pi camera"""
def record_video(duration: float, write_queue: queue.Queue, filename: str, 
                 initial_gain: float, initial_exposure: int,
                 stop_flag: threading.Event): 
    from picamera2 import Picamera2, Preview

    # Connect to and set up camera
    print(f"Initializing camera")
    cam: Picamera2 = initialize_camera(initial_gain, initial_exposure)
    gain_change_interval: float = 0.250 # the time between AGC adjustments 
    
    # Begin Recording and capture initial metadata 
    cam.start("video")  
    initial_metadata = cam.capture_metadata()
    current_gain, current_exposure = initial_metadata['AnalogueGain'], initial_metadata['ExposureTime']
    
    # Make absolutely certain Ae and AWB are off 
    # (had to put this here at some point) for it to work 
    cam.set_controls({'AeEnable':0, 'AwbEnable':0})     
    
    # Create containers to store the gain and exposure 
    # of every frame
    gain_history, exposure_history = [], [] 

    # Begin timing capture
    start_capture_time = time.time()
    last_gain_change = time.time()  
    
    # Capture duration (seconds) of frames
    frame_num = 1 
    while(True):
        # Capture the frame
        frame = cam.capture_array("raw")

        # Capture the current time
        current_time = time.time()

        # Append the frame and its relevant information 
        # to the storage containers
        write_queue.put((frame, frame_num, current_time, current_gain, current_exposure))
        gain_history.append(current_gain)
        exposure_history.append(current_exposure)
        
        # Change gain every N ms
        if((current_time - last_gain_change) > gain_change_interval):
            # Take the mean intensity of the frame
            mean_intensity = np.mean(frame, axis=(0,1))
            
            # Feed the settings into the the AGC 
            ret = AGC(mean_intensity, current_gain, current_exposure, 0.95)

            # Retrieve and set the new gain and exposure from our custom AGC
            new_gain, new_exposure = ret['adjusted_gain'], int(ret['adjusted_exposure'])
            cam.set_controls({'AnalogueGain': new_gain, 'ExposureTime': new_exposure}) 
            
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
    end_capture_time = time.time()
    
    # Signal the end of the write queue
    write_queue.put(None) 
    
    # Calculate the approximate FPS the frames were taken at 
    # (approximate due to time taken for other computation)
    observed_fps = frame_num/(end_capture_time-start_capture_time)
    print(f'I captured {frame_num} at {observed_fps} fps')
    
    # Stop recording and close the picam object 
    cam.close() 
    
    print('Finishing recording')
    
    # Write the metadata information to a settings file
    with open(f'{filename}_settingsHistory.pkl', 'wb') as f:
        pickle.dump({'gain_history': np.array(gain_history),
                     'exposure_history': np.array(exposure_history)},
                     f)
    
"""Connect to the camera and initialize a control object"""
def initialize_camera(initial_gain: float, initial_exposure: int) -> object:
    from picamera2 import Picamera2, Preview

    # Initialize camera 
    cam: Picamera2 = Picamera2()
    
    # Select the mode to put the sensor in
    # (ie, mode for high fps/low res, more pixel HDR etc)
    sensor_mode: dict = cam.sensor_modes[4]		
    
    # Set the mode
    cam.configure(cam.create_video_configuration(sensor={'output_size':sensor_mode['size'], 'bit_depth':sensor_mode['bit_depth']}, main={'size':sensor_mode['size']}, raw=sensor_mode))
    
    # Ensure the frame rate; This is calculated by
    # FPS = 1,000,000 / FrameDurationLimits 
    # e.g. 206.65 = 1000000/FDL => FDL = 1000000/206.65
    # 200 = 
    frame_duration_limit = int(np.ceil(1000000/200)) #int(np.ceil(1000000/sensor_mode['fps']))
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
