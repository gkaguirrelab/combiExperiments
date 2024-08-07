#from picamera2 import Picamera2, Preview
import time
import cv2
import matplotlib.pyplot as plt
import numpy as np
import os
import re
from scipy.io import loadmat, savemat
import argparse 
import pickle
from scipy.interpolate import interp1d

CAM_FPS = 206.65

"""Parse command line arguments when script is called via command line"""
def parse_args():
    parser = argparse.ArgumentParser(description="Analyze Temporal Sensitivity of the camera")
    
    parser.add_argument('recordings_dir', type=str, help="Path to where the camera recordings are stored")
    parser.add_argument('experiment_filename', type=str, help="Name of the experiment to analyze Temporal Sensitivity for")
    parser.add_argument('low_bound_ndf', type=str, help="The lower bound of the light levels/NDF range")
    parser.add_argument('high_bound_ndf', type=str, help="The high bound of the light levels/NDF range")
    parser.add_argument('save_path', type=str, help="The path to where to output the graph and experiment results")

    args = parser.parse_args()

    return args.recordings_dir, args.experiment_filename, args.low_bound_ndf, args.high_bound_ndf, args.save_path

def plot_intensity_over_time(frames: list, save_path: str):
	print(f"Frames: {len(frames)} | Frame shape:")
	#frame_avgs = [np.mean(frame, axis=(0,1)) for frame in frames]
	plt.plot(range(0, len(frames)), frames)
	plt.savefig(save_path)

"""Reconstruct a video from a series of frames"""
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
    cv2.destroyAllWindows()

"""Parse a video in .avi format to a series of frames 
   in np.array format"""
def parse_video(path_to_video: str, pixel_indices: np.array=None) -> np.array:
    # Initialize a video capture object
    video_capture = cv2.VideoCapture(path_to_video)

    # Create a container to store the frames as they are read in
    frames = []

    while(True):
        # Attempt to read a frame from the video file
        ret, frame = video_capture.read()

        # If read in valid, we are 
        # at the end of the video, break
        if(not ret): break 

        # Otherwise, append the frame 
        # to the frames containers
        frames.append(frame)

    # Close the video capture object 
    video_capture.release()
    
    # Convert frames to standardized np.array
    frames = np.array(frames, dtype=np.uint8)
    
    # Select only one channel as pixel intensity value, since 
    # the grayscale images are read in as RGB, all channels are equal, 
    # just choose the first one
    frames = frames[:,:,:,0]

    # If we simply want the entire images, return them now 
    if(pixel_indices is None): return frames
    
    # Otherwise, splice specific pixel indices
    pixel_rows = pixel_indices // frames.shape[1]
    pixel_cols = pixel_indices % frames.shape[1]

    frames = frames[:, pixel_rows, pixel_cols]

    return frames
    


def str2ndf(ndf_string: str) -> float:
    return float(ndf_string.replace("x", "."))

def parse_recording_filename(filename: str) -> dict:
    fields: list = ["experiment_name", "frequency", "NDF"]
    tokens: list = filename.split("_")

    tokens[1] = float(tokens[1][:3])
    tokens[2] = float(tokens[-1][:-7].replace("x","."))

    return {field: token for field, token in zip(fields, tokens)}

def read_light_level_videos(recordings_dir: str, experiment_filename: str, light_level: str) -> tuple:
    frequencies_and_videos: dict = {}

    for file in os.listdir(recordings_dir):
        experiment_info: dict = parse_recording_filename(file)

        if(experiment_info["experiment_name"] != experiment_filename):
            continue 
        
        if(experiment_info["NDF"] != str2ndf(light_level)):
            continue 
        
        frequencies_and_videos[experiment_info["frequency"]] = parse_video(os.path.join(recordings_dir, file))

    sorted_by_frequencies: list = sorted(frequencies_and_videos.items())

    frequencies: list = []
    videos: list = []
    for (frequency, video) in sorted_by_frequencies:
        frequencies.append(frequency)
        videos.append(video)

    return frequencies, videos

def fit_source_modulation(signal: np.array, light_level: str, frequency: float) -> float:     
    # Define time-related information regarding the signal
    duration: float = signal.shape[0] / CAM_FPS 
    secsPerMeasure: float = duration / signal.shape[0]

    # Set up a dictionary with relevant information about the 
    # signal to outsource for MATLAB's fitting code
    data = {'signal': signal, 'fps': CAM_FPS,
            'light_level': light_level, 'frequency': frequency,
            'elapsed_seconds': duration, 'secsPerMeasure': secsPerMeasure}
    
    # Save the dictionary to a temp file
    with open('temp.pkl', 'wb') as file:
        pickle.dump(data, file)

    # Execute the MATLAB subscript as defined and wait for it 
    # to finish executing
    path_to_matlab = r'/Applications/MATLAB_R2024a.app/bin/matlab'
    flags = '-r' #flags = '-nodisplay -nosplash -nodesktop -r'
    subscript_name = 'fit_source_modulation'
    os.system(f'{path_to_matlab} {flags} "{subscript_name};exit"')

    # Load in the resulting calculations from MATLAB
    fit_data = loadmat('temp.mat')['temp_data']

    # Delete the now uncessary temp files 
    os.remove('temp.pkl')
    os.remove('temp.mat')
    
    # Return the amplitude of the fit (bunch of subscripts because stored as nested arrays)
    return fit_data['amplitude'][0][0][0][0]    
   
"""Analyze the temporal sensitivity of a single light level, showing fit of 
   source modulation to observed and TS plot across different frequencies 
   at a single light level"""
def analyze_temporal_sensitivity(recordings_dir: str, experiment_filename: str, light_level: str) -> tuple:
    # Read in the videos at different frequencies 
    (frequencies, videos) = read_light_level_videos(recordings_dir, experiment_filename, light_level)

    # Assert we read in some videos
    assert len(videos) != 0 

    # Assert all of the videos are grayscale 
    assert all(len(vid.shape) == 3 for vid in videos)
    
    amplitudes = []
    for ind, (frequency, video) in enumerate(zip(frequencies, videos)):
        # Construct a video in which each frame is the scalar of avg intensity of that frame
        avg_video: np.array = np.mean(video, axis=(1,2))

        if(frequency != 12):
            continue

        # Fit the source modulation to the observed for this frequency, 
        # and find the amplitude
        amplitude = fit_source_modulation(avg_video, light_level, frequency)
        
        # Append this amplitude to the running list
        amplitudes.append(amplitude)

    # Convert amplitudes to standardized np.array
    amplitudes = np.array(amplitudes, dtype=np.float64)

    # Plot the TTF for one light level
    plt.clf()
    plt.plot(np.log10(frequencies), amplitudes, linestyle='-', marker='o')
    plt.ylim(bottom=0)
    plt.xlabel('Frequency [log]')
    plt.ylabel('Amplitude')
    plt.title(f'Amplitude by Frequency [log] {light_level}NDF')
    plt.show(block=False)

    # Display the plot for 3 seconds
    plt.pause(3)
    
    # Close the plot and clear the canvas
    plt.close()
    plt.clf()

    return frequencies, amplitudes

"""Analyze the temporal sensitivity of the camera, showing
   fit of source modulation to observed and TS plot across 
   frequencies at different light_levels"""
def generate_TTF(recordings_dir: str, experiment_filename: str, light_levels: tuple, save_dir: str): 
    light_level_ts_map = {str2ndf(light_level): analyze_temporal_sensitivity(recordings_dir, experiment_filename, light_level)
                          for light_level in light_levels}
    
    plt.clf()
    for light_level, (frequencies, amplitudes) in light_level_ts_map.items():
        plt.plot(np.log10(frequencies), amplitudes, linestyle='-', marker='o', label=f"{light_level}NDF")

    plt.xlabel("Frequency [log]")
    plt.ylabel("Amplitude")
    plt.title("Camera TTF Plot")
    plt.legend()
    plt.show()



"""
#Record a video from the raspberry pi camera
def record_video(output_path: str, duration: float):
    # # Begin Recording 
    cam = initialize_camera()
    cam.start("video")
    
    # Initialize array to hold video frames
    frames = []
    
    # Begin timing capture
    start_capture_time = time.time()
    
    # Record frames and append them to frames array  
    while(True):
        frame = cam.capture_array("raw")
        frames.append(frame)
        
        current_time = time.time()
        
        # If recording longer than duration, stop
        if((current_time - start_capture_time) > duration):
            break    

    # Record timing of end of capture 
    end_capture_time = time.time()
    
    # Convert frames to standardized np.array
    frames = np.array(frames, dtype=np.uint8)    
    
    # Calculate the approximate FPS the frames were taken at 
    # (approximate due to time taken for other computation)
    observed_fps = frames.shape[0]/(end_capture_time-start_capture_time)
    print(f'I captured {len(frames)} at {observed_fps} fps')
    
    # Assert that we captured the frames at the target FPS,
    # with margin of error
    assert abs(CAM_FPS - observed_fps) < 10     
    
    # Assert the images are grayscale (as they should be 
    # for raw images)
    assert len(frames.shape) == 3 
    
    # Stop recording and close the picam object 
    cam.close() 
    
    # Save the raw video frames
    np.save(output_path, frames)

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
"""

def main():    
    recordings_dir, experiment_filename, low_bound_ndf, high_bound_ndf, save_path = parse_args()

    analyze_temporal_sensitivity(recordings_dir, experiment_filename, high_bound_ndf)

    #generate_TTF(recordings_dir, experiment_filename, [low_bound_ndf, '2', high_bound_ndf], save_path)

if(__name__ == '__main__'):
    main()
