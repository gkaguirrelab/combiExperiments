import time
import os 
import cv2 
from picamera2 import Picamera2, Preview
import queue
from natsort import natsorted
import numpy as np
import sys

# Import the custom AGC library
agc_lib_path = os.path.join(os.path.dirname(__file__), 'AGC_lib')
sys.path.append(os.path.abspath(agc_lib_path))
from PyAGC import AGC

CAM_FPS = 206.65

def write_frame(write_queue, output_path):
    # Create output directory for frames + metadata    
    if(not os.path.exists(output_path)):
        os.mkdir(os.path.basename(output_path))
    

    # Initialize container for per-frame info
   
    while(True):  
        ret = write_queue.get()

        if(ret is None):
            print('BREAKING WRITING')
            break
        

        frame, frame_num = ret
        save_path = os.path.join(output_path, f"{frame_num}.tiff")
        print(f'writing {save_path}')

        cv2.imwrite(save_path, frame)

    # Close the metadata file
    print('finishing writing')

def vid_array_from_file(path: str):
    frames = [cv2.imread(os.path.join(path, frame)) for frame in natsorted(os.listdir(path)) ] 
    
    return np.array(frames, dtype=np.uint8)


def reconstruct_video(video_frames: np.array, output_path: str):
    # Define the information about the video to use for writing
    fps = CAM_FPS  # Frames per second of the camera to reconstruct
    height, width = video_frames[0].shape[:2]

    # Initialize VideoWriter object to write frames to
    out = cv2.VideoWriter(output_path, 0, fps, (width, height), isColor=len(video_frames.shape) > 3)

    # Write all of the frames to the video
    for i in range(video_frames.shape[0]):
        out.write(video_frames[i])

    # Release the VideoWriter object
    out.release()

#Record a video from the raspberry pi camera
def record_video(duration: float, write_queue: queue.Queue):        
    # Connect to and set up camera
    print(f"Initializing camera")
    cam = initialize_camera()
    gain_change_interval: float = 0.250
    
    # Begin Recording 
    cam.start("video")  
    initial_metadata = cam.capture_metadata()
    current_gain, current_exposure = initial_metadata['AnalogueGain'], initial_metadata['ExposureTime']
    cam.set_controls({'AeEnable':0})     
    
    # Begin timing capture
    start_capture_time = time.time()
    last_gain_change = time.time()  
    
    # Capture 10 seconds of frames
    frame_num = 1 
    while(True):
        # Capture the frame
        print(f'capturing frame {frame_num}')
        frame = cam.capture_array("raw")

        write_queue.put((frame, frame_num))

        # Capture the current time
        current_time = time.time()
        
        # Change gain every N ms
        if((current_time - last_gain_change)  > gain_change_interval):
            mean_intensity = np.mean(frame, axis=(0,1))
            
            ret = AGC(mean_intensity, current_gain, current_exposure, 0.2)
            new_gain, new_exposure = ret['adjusted_gain'], int(ret['adjusted_exposure'])
            cam.set_controls({'AnalogueGain': new_gain, 'ExposureTime': new_exposure}) 
            

            last_gain_change = current_time
            current_gain, current_exposure = new_gain, new_exposure
        
        # If reached desired duration, stop recording
        if((current_time - start_capture_time) > duration):
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
    
    
    # Reconstruct the video from the frames  
    # and save the video 
    #reconstruct_video(frames, os.path.join(output_path, avi))

def initialize_camera() -> Picamera2:
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
    frame_duration_limit = int(np.ceil(1000000/sensor_mode['fps']))
    cam.video_configuration.controls['NoiseReductionMode'] = 0
    cam.video_configuration.controls['FrameDurationLimits'] = (frame_duration_limit,frame_duration_limit) # *2 for lower,upper bound equal
    
    # Set runtime camera information, such as auto-gain
    # auto exposure, white point balance, etc
    gain = 1.0
    exposure = 1000
    # Note, AeEnable changes both AEC and AGC		
    cam.video_configuration.controls['AwbEnable'] = 0
    cam.video_configuration.controls['AeEnable'] = 0  
    cam.video_configuration.controls['AnalogueGain'] = gain
    cam.video_configuration.controls['ExposureTime'] = exposure
    
    return cam
