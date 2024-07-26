from picamera2 import Picamera2, Preview
import time
import cv2
import matplotlib.pyplot as plt
import numpy as np

CAM_FPS = 206.65

def parse_video(path_to_video: str) -> np.array:
    fourcc = cv2.VideoWriter_fourcc(*'H264')
    video_capture = cv2.VideoCapture(path_to_video)
    video_capture.set(cv2.CAP_PROP_FOURCC, fourcc)

    frames = []
    while(True):
        ret, frame = video_capture.read()

        if(not ret): break 

        frames.append(frame)

    video_capture.release()

    return np.array(frames, dtype=np.uint8)

def analyze_temporal_sensitivity(video_frames: np.array):
    # Convert video sequence to grayscale
    grayscale_video: np.array = np.array([cv2.cvtColor(video_frames[i], cv2.COLOR_BGR2GRAY) for i in range(video_frames.shape[0])], dtype=np.uint8)

    # Find average intensity of every frame in the video
    average_frame_intensities: np.array = np.mean(grayscale_video, axis=(1,2))

    """Express both source and observed values as power spectrum"""
    frequency: int = 2  # frequency of the sinusoid in Hz
    amplitude: int = 50   # amplitude of the sinusoid
    phase: int = 0       # phase shift in radians
    sampling_rate:int = 1000  # samples per second
    duration: float = video_frames.shape[0] / CAM_FPS  # duration of the signal in seconds

    # Generate mock source time values and sinusoidal wave 
    t_source: np.array = np.linspace(0, duration, int(sampling_rate*duration), endpoint=False)
    y_source: np.array = amplitude * np.sin(2 * np.pi * frequency * t_source + phase)   

    # Generate x values in time for the measured points    
    t_measured: np.array = np.linspace(0,duration,video_frames.shape[0],endpoint=False)
    
    """"""

    # Plot the mock source data 
    plt.plot(t_source, y_source, label='Source Modulation')

    # Plot the observed data 
    plt.plot(t_measured, average_frame_intensities, label='Avg Intensity')

    plt.title('Camera Chip Temporal Sensitivity')
    plt.xlabel('Time (seconds)')
    plt.ylabel('Amplitude')
    plt.legend()
    plt.show()

def record_video(cam: Picamera2, output_path: str):
    # Begin Recording
    cam.start("video")
    
    # Initialize array to hold video frames
    frames = []
    
    # Begin timing capture
    start_capture_time = time.time()
    
    # Record frames and append them to frames array 
    # until user presses control-C 
    try:
        while(True):
            array = cam.capture_array("raw")
    
            frames.append(array)
    except:
        pass 
    
    # Record timing of end of capture 
    end_capture_time = time.time()
    
    # Calculate the approximate FPS the frames were taken at 
    # (approximate due to time taken for other computation)
    observed_fps = len(frames)/(end_capture_time-start_capture_time)
    print(f'I captured {len(frames)} at {observed_fps} fps')
    
    # Assert that we captured the frames at the target FPS,
    # with margin of error
    assert abs(CAM_FPS - observed_fps) < 10 
    
    # Stop recording and close the picam object 
    cam.close()    
    
    np.save(output_path,np.array(frames, dtype=np.uint8))
    
    
def initialize_camera() -> Picamera2:
    # Initialize camera 
    cam: Picamera2 = Picamera2()
    
    # Select the mode to put the sensor in
    # (ie, mode for high fps/low res, more pixel HDR etc)
    sensor_mode: dict = cam.sensor_modes[4]		
    
    # Set the mode
    cam.configure(cam.create_video_configuration(sensor={'output_size':sensor_mode['size'], 'bit_depth':sensor_mode['bit_depth']}, raw=sensor_mode))
    
    # Ensure the frame rate; This is calculated by
    # FPS = 1,000,000 / FrameDurationLimits 
    # e.g. 206.65 = 1000000/FDL => FDL = 1000000/206.65
    frame_duration_limit = int(np.ceil(1000000/sensor_mode['fps']))
    
    cam.video_configuration.controls['FrameDurationLimits'] = (frame_duration_limit,frame_duration_limit) # *2 for lower,upper bound equal
    
    # Set runtime camera information, such as auto-gain
    # auto exposure, white point balance, etc
    cam.set_controls({'AeEnable':True, 'AwbEnable':False}) # Note, AeEnable changes both AEC and AGC
    
    return cam

def main():
    # Initialize camera with our desired
    # settings
    cam: Picamera2 = initialize_camera()
    
    # Prepare encoder and output filename
    output_file: str = './test.npy'
    
    record_video(cam, output_file)

    #frames = parse_video(output_file)
    #analyze_temporal_sensitivity(frames)

if(__name__ == '__main__'):
    main()
