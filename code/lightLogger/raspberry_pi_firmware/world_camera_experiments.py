import picamera2
import numpy as np
import time
import uvc
import os

WORLD_CAM_FPS: int = 200
WORLD_FRAME_SHAPE: np.ndarray = np.array([640,480], dtype=np.uint16)

"""Connect to the camera and initialize a control object"""
def initialize_world_camera(initial_gain: float=2, initial_exposure: int=4839) -> picamera2.Picamera2: # regularly, these should be 1, 100
    # Initialize camera 
    cam: picamera2.Picamera2 = picamera2.Picamera2()
    
    # Select the mode to put the sensor in
    # (ie, mode for high fps/low res, more pixel HDR etc)
    sensor_mode: dict = cam.sensor_modes[4] # 4		
    
    # Set up the streaming configuration
    cam.configure(cam.create_video_configuration(sensor={'output_size':sensor_mode['size'], 'bit_depth':sensor_mode['bit_depth']}, 
                                                 main={'size':sensor_mode['size']}, 
                                                 raw=sensor_mode,
                                                 )
                 )
  
    # Ensure the frame rate; This is calculated by
    # FPS = 1,000,000 / FrameDurationLimits 
    # e.g. 206.65 = 1000000/FDL => FDL = 1000000/206.65
    # 200 = 
    frame_duration_limit: int = 1000000//WORLD_CAM_FPS # Should output an integer 5000 for 200 FPS
    assert(frame_duration_limit == 5000)

    cam.video_configuration.controls['NoiseReductionMode'] = 0
    cam.video_configuration.controls['FrameDurationLimits'] = (frame_duration_limit,frame_duration_limit) # for lower,upper bound equal
    
    # Set runtime camera information, such as auto-gain
    # auto exposure, white point balance, etc
    # Note, AeEnable changes both AEC and AGC		
    cam.video_configuration.controls['AwbEnable'] = 0
    cam.video_configuration.controls['AeEnable'] = 0  

    # HARDCODED FOR THE TEST
    cam.video_configuration.controls['AnalogueGain'] = 2
    cam.video_configuration.controls['ExposureTime'] = 4839
    
    return cam, sensor_mode['size']


def initialize_pupil_camera() -> uvc.Capture:
    # Retrieve the camera device
    device, *_ = uvc.device_list()

    # Open a connection to the camera
    cam: uvc.Capture = uvc.Capture(device["uid"])

    cam.frame_mode = cam.available_modes[5]         # 5 is the target, -1 works though

    # Retrieve the controls dict
    controls_dict: dict = {c.display_name: c for c in cam.controls}

    # Configure the 200hz IR cameras 
    controls_dict['Auto Exposure Mode'].value = 1
    controls_dict["Auto Focus"].value = 1

    return cam 

def record_pupil(cam: uvc.Capture, buffer: np.ndarray, 
                 total_duration: int) -> None:
    
    # Denote the start time of recording
    start_time: float = time.time()

    while(True):
        # Capture the current time
        current_time: float = time.time()

        if(current_time - start_time >= total_duration):
            break 
        
        # Capture the frame
        frame_obj: uvc_bindings.MJPEGFrame = cam.get_frame_robust()

        print(dir(frame_obj))
        print(frame_obj.gray)



# Record a video for a set duration and populate a buffer 
def record_world(cam: picamera2.Picamera2, buffer: np.ndarray, 
                 total_duration: int, chunk_duration: int, downtime_duration: int) -> None:
  
    # Calculate how many chunks we will record 
    assert(total_duration % chunk_duration == 0)
    num_chunks: int = total_duration // chunk_duration

    # Record for the desired number of chunks 
    for i in range(num_chunks):
        # Track which frame number we're on
        frame_num: int = 0
        
        # Define the start time of the capture 
        start_time: float = time.time()

        # Start the capture 
        cam.start('video')
        while(True):
            # Retrieve the current time 
            current_time: float = time.time()

            if(current_time - start_time >= chunk_duration):
                break 

            # Retrieve the frame from the camera 
            frame: np.ndarray = cam.capture_array('raw')[:, 1::2]
            
            # Save it into the buffer 
            buffer[frame_num] = frame

            # Increment the frame number 
            frame_num += 1 

        # Stop capture while we output the buffer 
        cam.stop()

        # Output the result
        start_write_time: float = time.time()
        np.save(os.path.join(os.path.dirname(__file__), "/media/rpiControl/FF5E-7541/test_folder", f"chunk_{i}.npy"), buffer[:frame_num])
        end_write_time: float = time.time() 

        time.sleep(downtime_duration - (end_write_time - start_write_time))

    return 


def main():
    # The duration of the recording in seconds
    total_duration: int = 300 # 5mins 

    # The duration of chunks in seconds 
    chunk_duration: int = 60 # 1 min chunks 

    # The standardized amount of downtime in seconds 
    downtime_duration: int = 15

    # Initialize the camera
    print("Initializing Camera")
    
    cam = initialize_pupil_camera()
    #cam, frame_shape = initialize_camera()

    # Allocate the buffer of memory
    print("Allocating Buffer") 
    buffer: np.ndarray = np.empty(((chunk_duration + 1) * WORLD_CAM_FPS, *WORLD_FRAME_SHAPE), dtype=np.uint8)
    
    # Record for the desired duration and fill the buffer 
    print("Recording")
    record_pupil(cam, buffer, total_duration)
    #record_world(cam, buffer, total_duration, chunk_duration, downtime_duration)
    #cam.close()

    # Output the buffer 
    print("Saving")
    #np.save(os.path.join(os.path.dirname(__file__), 'test.npy'), buffer) 

if(__name__ == "__main__"):
    main()


