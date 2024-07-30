#from picamera2.encoders import H264Encoder
#from picamera2 import Picamera2, Preview
import time
import cv2
import matplotlib.pyplot as plt
from scipy.signal import correlate
import numpy as np
import inspect 
from scipy.signal import hilbert

CAM_FPS = 206.65

def reconstruct_video(video_frames: np.array, output_path: str):
    # Define the information about the video to use for writing
    #fourcc = cv2.VideoWriter_fourcc(*'mp4v')  # You can use other codecs like 'mp4v', 'MJPG', etc.
    fps = CAM_FPS  # Frames per second of the camera to reconstruct
    height, width = video_frames[0].shape[:2]

    # Initialize VideoWriter object to write frames to
    out = cv2.VideoWriter(output_path, 0, fps, (width, height), isColor=True)

    for i in range(video_frames.shape[0]):
        out.write(video_frames[i])  # Write the frame to the video

    # Release the VideoWriter object
    out.release()
    cv2.destroyAllWindows()

# Read in a video as a series of frames in np.array format
def read_in_video(path_to_video: str) -> np.array:
    return np.load(path_to_video)

# Parse a video in H264 format to a series of frames 
# in np.array format 
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

# Analyze the temporal sensitivity of the camera 
def analyze_temporal_sensitivity(video_frames: np.array):
    # Convert video sequence to grayscale (if not already)  

    grayscale_video: np.array = video_frames if(len(video_frames.shape) == 3) else np.array([cv2.cvtColor(video_frames[i], cv2.COLOR_RGB2GRAY) for i in range(video_frames.shape[0])], dtype=np.uint8)

    # Find average intensity of every frame in the video
    average_frame_intensities: np.array = np.mean(grayscale_video, axis=(1,2))

    """Express both source and observed values as power spectrum"""
    frequency: int = 2  # frequency of the sinusoid in Hz
    amplitude: int = np.max(average_frame_intensities) - np.mean(average_frame_intensities)   # amplitude of the sinusoid
    phase: int = 0       # phase shift in radians
    sampling_rate:int = 1  # samples per second
    duration: float = video_frames.shape[0] / CAM_FPS  # duration of the signal in seconds

    # Generate mock source time values and sinusoidal wave 
    t_source: np.array = np.linspace(0, duration, video_frames.shape[0], endpoint=False)
    y_source: np.array = amplitude * np.sin(2 * np.pi * frequency * t_source + phase)  + np.mean(average_frame_intensities)

    # Generate x values in time for the measured points    
    t_measured: np.array = np.linspace(0,duration,video_frames.shape[0],endpoint=False)+0.1
    y_measured = average_frame_intensities 

    # Fit measured to source by finding the difference in phase shift 
    # between the two waves
    source_analytic_signal = hilbert(y_source)  # use hilbert transform since it works for imperfect sine waves
    measured_analytic_signal = hilbert(y_measured)

    instantaneous_phase1 = np.unwrap(np.angle(source_analytic_signal))
    instantaneous_phase2 = np.unwrap(np.angle(measured_analytic_signal))
    
    phase_difference = instantaneous_phase2 - instantaneous_phase1
    average_phase_difference = np.mean(phase_difference)
    
    """"""

    # Plot the mock source data 
    plt.plot(t_source, y_source, label='Source Modulation')

    # Plot the observed data 
    plt.plot(t_measured, y_measured, label='Avg Intensity')

    plt.title('Camera Temporal Sensitivity (2Hz)')
    plt.xlabel('Time (seconds)')
    plt.ylabel('Amplitude')
    plt.legend()
    plt.show()


def record_video(output_path: str, duration: float):
    # Initialize a camera 
    cam: Picamera2 = initialize_camera()
    encoder = H264Encoder(bitrate=10000000, framerate=206.65)
    
    # Initialize array to hold video frames
    frames = []
    
    # Begin recording and begin timing
    start_capture_time = time.time()
    cam.start_encoder(encoder, output_path)
    cam.start('video')
    
    # Record for the given duration
    time.sleep(duration)
    
    # Finish recording and record end time
    cam.stop_recording()
    end_capture_time = time.time()
    
    # Read parse the video into frames 
    print(f"parsing")
    frames = parse_video(output_path)    
    
    # Calculate the approximate FPS the frames were taken at 
    # (approximate due to time taken for other computation)
    observed_fps = len(frames)/(end_capture_time-start_capture_time)
    print(f'I captured {len(frames)} at ~{observed_fps} fps')       
        
    # Convert frames to standardized np.array
    frames_as_np = np.array(frames, dtype=np.uint8)
    
    print(f"The shape of frames is: {frames_as_np.shape}")   
    
    # Assert that we captured the frames at the target FPS,
    # with margin of error
    assert abs(CAM_FPS - observed_fps) < 10 
    
    # Ensure we captured an RGB video 
    assert len(frames_as_np.shape) == 4     
    
    # Close the camera object
    cam.close()    
    

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
    
    cam.video_configuration.controls['FrameDurationLimits'] = (frame_duration_limit,frame_duration_limit) # *2 for lower,upper bound equal
    
    # Set runtime camera information, such as auto-gain
    # auto exposure, white point balance, etc
    cam.set_controls({'AeEnable':True, 'AwbEnable':False}) # Note, AeEnable changes both AEC and AGC
    
    return cam
    

def main():    
    # Prepare encoder and output filename
    output_file: str = './2hz_2NDF.h264'    
    
    #record_video(cam, output_file)

    frames = parse_video(output_file)
    #frames = read_in_video(output_file)
    #reconstruct_video(frames, './my_video.avi')
    analyze_temporal_sensitivity(frames)

if(__name__ == '__main__'):
    main()
