from picamera2 import Picamera2, Preview
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
import multiprocessing as mp
from utility.PyAGC import AGC
from natsort import natsorted

#import matlab.engine

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



def write_frame(write_queue, output_path):
    # Create output directory for frames + metadata    
    if(not os.path.exists(output_path)):
        os.mkdir(os.path.basename(output_path))
    
    while(True):  
        ret = write_queue.get()

        if(ret is None):
            print('BREAKING WRITING')
            break

        frame, frame_num = ret
        save_path = os.path.join(output_path, f"{frame_num}.tiff")
        print(f'writing {save_path}')

        cv2.imwrite(save_path, frame)
        

    print('finishing writing')
        
def vid_array_from_file(path: str):
    frames = [cv2.imread(os.path.join(path, frame)) for frame in natsorted(os.listdir(path)) ] 
    
    return np.array(frames, dtype=np.uint8)

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
    
def parse_mean_video(path_to_video: str, pixel_indices: np.array=None) -> np.array:
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

        # Images read in as color by default => All channels 
        # equal since images were captured raw, so 
        # just take the first value to for every pixel
        frame = frame[:,:,0]

        # Find the mean of the given pixels per frame 
        if(pixel_indices is None or len(pixel_indices) == 0): pixel_indices = np.arange(0, frame.shape[0]*frame.shape[1])
        mean_frame = np.mean(frame.flatten()[pixel_indices])

        # Otherwise, append the frame 
        # to the frames containers
        frames.append(mean_frame)

    # Close the video capture object 
    video_capture.release()
    
    # Convert frames to standardized np.array
    frames = np.array(frames, dtype=np.uint8)

    return frames

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

def read_light_level_videos(recordings_dir: str, experiment_filename: str, light_level: str, parser: object) -> tuple:
    frequencies_and_videos: dict = {}

    print(f"Reading in {experiment_filename} {light_level}NDF videos...")

    for file in os.listdir(recordings_dir):
        experiment_info: dict = parse_recording_filename(file)

        if(experiment_info["experiment_name"] != experiment_filename):
            continue 
        
        if(experiment_info["NDF"] != str2ndf(light_level)):
            continue 
        
        frequencies_and_videos[experiment_info["frequency"]] = parser(os.path.join(recordings_dir, file))

    sorted_by_frequencies: list = sorted(frequencies_and_videos.items())

    frequencies: list = []
    videos: list = []
    for (frequency, video) in sorted_by_frequencies:
        frequencies.append(frequency)
        videos.append(video)

    return frequencies, videos

def fit_source_modulation(signal: np.array, light_level: str, frequency: float, ax: plt.Axes) -> tuple:     
    eng = matlab.engine.start_matlab()
    
    signal_mean = np.mean(signal)
    signal = (signal - signal_mean) / signal_mean

    signal_as_double: matlab.double = matlab.double(signal.astype(np.float64))
    frequency_as_double: matlab.double = matlab.double(frequency)

    observed_fps: matlab.double = eng.findObservedFPS(signal_as_double, frequency_as_double, nargout=1)
    observed_r2, observed_amplitude, observed_phase, observed_fit, observed_model_T, observed_signal_T = eng.fourierRegression(signal_as_double, frequency_as_double, observed_fps, nargout=6)
    
    eng.quit()
    
    observed_signal_T: np.array = np.array(observed_signal_T).flatten()
    observed_model_T: np.array = np.array(observed_model_T).flatten()
    observed_fit: np.array = np.array(observed_fit).flatten()

    ax.plot(observed_signal_T, signal-np.mean(signal), linestyle='-', label="Measured")
    ax.plot(observed_model_T, observed_fit, linestyle='-', label="Fit")
    ax.legend()
    ax.set_title(f"Measured vs Fit Modulation {light_level}NDF {frequency}hz")
    ax.set_xlabel('Time [seconds]')
    ax.set_ylabel('Contrast')

    return observed_amplitude, observed_phase, observed_fps

def analyze_temporal_sensitivity(recordings_dir: str, experiment_filename: str, light_level: str) -> tuple:
    print(f"Generating TTF : {light_level}NDF")

    # Read in the videos at different frequencies 
    (frequencies, mean_videos) = read_light_level_videos(recordings_dir, experiment_filename, light_level, parse_mean_video)

    # Assert we read in some videos
    assert len(mean_videos) != 0 

    # Assert all of the videos are grayscale 
    assert all(len(vid.shape) < 3 for vid in mean_videos)
    
    total_axes = len(frequencies)+1
    fig, axes = plt.subplots(total_axes, figsize=(18,16))
    amplitudes, videos_fps = [], []
    for ind, (frequency, mean_video) in enumerate(zip(frequencies, mean_videos)):
        print(f"Fitting Source vs Observed Modulation: {light_level}NDF {frequency}hz")

        # Fit the source modulation to the observed for this frequency, 
        # and find the amplitude
        observed_amplitude, observed_phase, observed_fps = fit_source_modulation(mean_video, light_level, frequency, axes[ind])
        
        # Append this amplitude to the running list
        amplitudes.append(observed_amplitude)
        videos_fps.append(observed_fps)

    # Convert amplitudes to standardized np.array
    amplitudes = np.array(amplitudes, dtype=np.float64)
    videos_fps = np.array(videos_fps, dtype=np.float32)

    # Plot the TTF for one light level
    ax = axes[-1]
    ax.plot(np.log10(frequencies), amplitudes, linestyle='-', marker='o', label='Observed Device')
    ax.set_ylim(bottom=0)
    ax.set_xlabel('Frequency [log]')
    ax.set_ylabel('Amplitude')
    ax.set_title(f'Amplitude by Frequency [log] {light_level}NDF')
    ax.legend()
    plt.subplots_adjust(hspace=2)

    plt.savefig(f'/Users/zacharykelly/Aguirre-Brainard Lab Dropbox/Zachary Kelly/FLIC_admin/Equipment/SpectacleCamera/calibration/graphs/TemporalSensitivity{light_level}NDF.png')
    #plt.show(block=False)

    # Display the plot for 3 seconds
    #plt.pause(10)
    
    # Close the plot and clear the canvas
    plt.close(fig)

    return frequencies, amplitudes, videos_fps

def generate_TTF(recordings_dir: str, experiment_filename: str, light_levels: tuple, save_dir: str): 
    light_level_ts_map = {str2ndf(light_level): analyze_temporal_sensitivity(recordings_dir, experiment_filename, light_level)
                          for light_level in light_levels}
    
    fig, (ax0, ax1) = plt.subplots(1,2, figsize=(10,8))
    eng = matlab.engine.start_matlab()
    for light_level, (frequencies, amplitudes, videos_fps) in light_level_ts_map.items():   
        ax1.plot(np.log10(frequencies), videos_fps, linestyle='-', marker='o', label=f"{light_level}NDF FPS")
        ax0.plot(np.log10(frequencies), amplitudes, linestyle='-', marker='o', label=f"{light_level}NDF_Obs")
        
    sourceFreqsHz = matlab.double(np.logspace(0,2,))
    dTsignal = 1/videos_fps[0]
    ideal_device_curve = np.array(eng.idealDiscreteSampleFilter(sourceFreqsHz, dTsignal)).flatten() * 0.5
    ax0.plot(np.log10(sourceFreqsHz).flatten(), ideal_device_curve, linestyle='-', marker='o', label=f"Ideal Device")

    eng.quit()

    ax0.set_xlabel("Frequency [log]")
    ax0.set_ylabel("Amplitude")
    ax0.set_title("Camera TTF Plot")
    ax0.legend()

    ax1.set_xlabel("Frequency [log]")
    ax1.set_ylabel("FPS")
    ax1.set_title("FPS by Frequency/Light Level")
    ax1.legend()

    plt.savefig('/Users/zacharykelly/Aguirre-Brainard Lab Dropbox/Zachary Kelly/FLIC_admin/Equipment/SpectacleCamera/calibration/graphs/CameraTemporalSensitivity.png')
    plt.show()

def generate_row_phase_plot(video: np.array, light_level: str, frequency: float):
    eng = matlab.engine.start_matlab()

    signal = np.mean(video, axis=(1,2))
    signal_as_double: matlab.double = matlab.double(signal.astype(np.float64))
    frequency_as_double: matlab.double = matlab.double(frequency)

    observed_fps: matlab.double = eng.findObservedFPS(signal_as_double, frequency_as_double, nargout=1)

    phases = []
    for r in range(video.shape[1]):
        row_video: np.array = np.mean(np.ascontiguousarray(video[:,r,:].astype(np.float64)), axis=1).flatten()

        print(f"Row_video shape {row_video.shape}")
        signal_as_double = matlab.double(row_video)

        observed_r2, observed_amplitude, observed_phase, observed_fit, observed_model_T, observed_signal_T = eng.fourierRegression(signal_as_double, frequency_as_double, observed_fps, nargout=6)
        phases.append(observed_phase)

    phases = np.array(phases)

    plt.plot(range(video.shape[1]), phases)
    plt.title('Phase by Row Number')
    plt.xlabel('Row Number')
    plt.ylabel('Phase')
    plt.show()

 
#Record a video from the raspberry pi camera
def record_video(duration: float, write_queue):        
    # Connect to and set up camera
    cam = initialize_camera()
    
    # Begin Recording 
    cam.start("video")  
    initial_metadata = cam.capture_metadata()
    current_gain, current_exposure = initial_metadata['AnalogueGain'], initial_metadata['ExposureTime']
    cam.set_controls({'AeEnable':0})     
    
    # Begin timing capture
    start_capture_time = time.time()
    last_gain_change = time.time()  
    
    frame_num = 0 
    # Record frames and append them to frames array  
    while(True):
        frame = cam.capture_array("raw")
        write_queue.put((frame, frame_num))
        #write_queue.put((frame, save_path)) 
        #print(f"capturing frame {frame_num}")
        
        #print(f'Len frame queue: {capture_queue.qsize()}')        
         
        current_time = time.time()
        
        # Experiment with changing gain on the fly 
        if((current_time - last_gain_change)  > 0.250):
            mean_intensity = np.mean(frame, axis=(0,1))
            
            ret = AGC(mean_intensity, current_gain, current_exposure, 0.7)
            new_gain, new_exposure = ret['adjusted_gain'], int(ret['adjusted_exposure'])
            cam.set_controls({'AnalogueGain': new_gain, 'ExposureTime': new_exposure}) 
            last_gain_change = current_time
            current_gain, current_exposure = new_gain, new_exposure
        	
        #change = (change + 1) % 2
        frame_num += 1 
        
        # If recording longer than duration, stop
        if((current_time - start_capture_time) > duration):
            break   
            
    # Record timing of end of capture 
    end_capture_time = time.time()
    
    write_queue.put(None)
    
    # Convert frames to standardized np.array
    #frames = np.array(frames, dtype=np.uint8)    
    
    # Calculate the approximate FPS the frames were taken at 
    # (approximate due to time taken for other computation)
    observed_fps = frame_num/(end_capture_time-start_capture_time)
    print(f'I captured {frame_num} at {observed_fps} fps')
    
    # Assert that we captured the frames at the target FPS,
    # with margin of error
    #assert abs(CAM_FPS - observed_fps) < 10     
    
    # Assert the images are grayscale (as they should be 
    # for raw images)
    #assert len(frames.shape) == 3 
    
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

def main():    
    recordings_dir, experiment_filename, low_bound_ndf, high_bound_ndf, save_path = parse_args()

    #analyze_temporal_sensitivity(recordings_dir, experiment_filename, high_bound_ndf)

    generate_TTF(recordings_dir, experiment_filename, ['1','1x5','1x7', '2'], save_path)

if(__name__ == '__main__'):
    main()
