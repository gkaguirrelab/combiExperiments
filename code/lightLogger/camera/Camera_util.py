import cv2
import matplotlib.pyplot as plt
import numpy as np
import os
import argparse 
import sys 
import matlab.engine
from natsort import natsorted

"""Import the FPS of the camera"""
agc_lib_path = os.path.join(os.path.dirname(__file__))
from recorder import CAM_FPS

"""Parse command line arguments when script is called via command line"""
def parse_args() -> tuple:
    parser: argparse.ArgumentParser = argparse.ArgumentParser(description="Analyze Temporal Sensitivity of the camera")
    
    parser.add_argument('recordings_dir', type=str, help="Path to where the camera recordings are stored")
    parser.add_argument('experiment_filename', type=str, help="Name of the experiment to analyze Temporal Sensitivity for")
    parser.add_argument('low_bound_ndf', type=str, help="The lower bound of the light levels/NDF range")
    parser.add_argument('high_bound_ndf', type=str, help="The high bound of the light levels/NDF range")
    parser.add_argument('save_path', type=str, help="The path to where to output the graph and experiment results")

    args = parser.parse_args()

    return args.recordings_dir, args.experiment_filename, args.low_bound_ndf, args.high_bound_ndf, args.save_path

"""Parse video file starting as start_frame as mean of certain pixels of np.array"""
def parse_mean_video(path_to_video: str, start_frame: int=0, pixel_indices: np.array=None) -> np.array:
    # Initialize a video capture object
    video_capture: cv2.videoCapture = cv2.VideoCapture(path_to_video)

    # Create a container to store the frames as they are read in
    frames: list = []

    while(True):
        # Attempt to read a frame from the video file
        ret, frame = video_capture.read()

        # If read in valid, we are 
        # at the end of the video, break
        if(not ret): break 

        # Images read in as color by default => All channels 
        # equal since images were captured raw, so 
        # just take the first value to for every pixel
        frame: np.array = frame[:,:,0]

        # Find the mean of the given pixels per frame 
        if(pixel_indices is None or len(pixel_indices) == 0): 
            pixel_indices = np.arange(0, frame.shape[0]*frame.shape[1])
        mean_frame = np.mean(frame.flatten()[pixel_indices])

        # Append the mean frame to the frames list
        frames.append(mean_frame)

    # Close the video capture object 
    video_capture.release()
    
    # Convert frames to standardized np.array
    frames = np.array(frames, dtype=np.uint8)

    return frames[start_frame:]

"""Parse video file starting as start_frame of certain pixels of np.array"""
def parse_video(path_to_video: str, start_frame: int=0, pixel_indices: np.array=None) -> np.array:
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
    frames = frames[start_frame:,:,:,0]

    # If we simply want the entire images, return them now 
    if(pixel_indices is None): return frames
    
    # Otherwise, splice specific pixel indices
    pixel_rows = pixel_indices // frames.shape[1]
    pixel_cols = pixel_indices % frames.shape[1]

    frames = frames[:, pixel_rows, pixel_cols]

    return frames

"""Convert a given str NDF representation to its float value"""
def str2ndf(ndf_string: str) -> float:
    return float(ndf_string.replace("x", "."))

"""Parse an experiment filename to find its relevant info"""
def parse_recording_filename(filename: str) -> dict:
    fields: list = ["experiment_name", "frequency", "NDF"]
    tokens: list = filename.split("_")

    # Ignore the 'hz' in the frequency token
    tokens[1] = float(tokens[1][:-2])
    # Ignore file extension and the letters NDF in the NDF token 
    tokens[2] = str2ndf(tokens[-1][:-7])

    return {field: token for field, token in zip(fields, tokens)}

"""Read all videos in of a certain light level"""
def read_light_level_videos(recordings_dir: str, experiment_filename: str, 
                            light_level: str, parser: object) -> tuple:
    # Create container to map frequencies and their videos
    frequencies_and_videos: dict = {}

    print(f"Reading in {experiment_filename} {light_level}NDF videos...")

    # Read in all the files in the recording dir
    for file in os.listdir(recordings_dir):
        if(file == '.DS_Store'): continue
        
        # Parse the experiment information out of the filename
        experiment_info: dict = parse_recording_filename(file)

        # If the video isn't from the target experiment, skip 
        if(experiment_info["experiment_name"] != experiment_filename):
            continue 
        
        # If the video is not from this light_level, skip 
        if(experiment_info["NDF"] != str2ndf(light_level)):
            continue 
        
        # Parse the video and pair it with its frequency 
        frequencies_and_videos[experiment_info["frequency"]] = parser(os.path.join(recordings_dir, file))

    # Sort the videos by their frequencies
    sorted_by_frequencies: list = sorted(frequencies_and_videos.items())

    # Split the two back into seperate lists
    frequencies: list = []
    videos: list = []
    for (frequency, video) in sorted_by_frequencies:
        frequencies.append(frequency)
        videos.append(video)

    return frequencies, videos

"""Fit the source modulation to the observed and plot the fit"""
def fit_source_modulation(signal: np.array, light_level: str, frequency: float, ax: plt.Axes) -> tuple:     
    # Start the MATLAB engine
    eng = matlab.engine.start_matlab()
    
    # Convert signal to contrast
    signal_mean = np.mean(signal)
    signal = (signal - signal_mean) / signal_mean
    
    # Fit the data
    observed_r2, observed_amplitude, observed_phase, observed_fit, observed_model_T, observed_signal_T = eng.fourierRegression(matlab.double(signal), 
                                                                                                                               matlab.double(frequency), 
                                                                                                                               matlab.double(CAM_FPS), 
                                                                                                                               nargout=6)

    # Close the MATLAB engine 
    eng.quit()
    
    # Convert returned data back to Python datatype 
    observed_signal_T: np.array = np.array(observed_signal_T).flatten()
    observed_model_T: np.array = np.array(observed_model_T).flatten()
    observed_fit: np.array = np.array(observed_fit).flatten()

    # Plot the fit on a given axis 
    ax.plot(observed_signal_T, signal-np.mean(signal), linestyle='-', label="Measured")
    ax.plot(observed_model_T, observed_fit, linestyle='-', label="Fit")
    ax.legend()
    ax.set_title(f"Measured vs Fit Modulation {light_level}NDF {frequency}hz")
    ax.set_xlabel('Time [seconds]')
    ax.set_ylabel('Contrast')

    return observed_amplitude, observed_phase

"""Analyze the temporal sensitivity of a given light level, fit source vs observed for all frequencies"""
def analyze_temporal_sensitivity(recordings_dir: str, experiment_filename: str, light_level: str) -> tuple:
    print(f"Generating TTF : {light_level}NDF")

    # Read in the videos at different frequencies 
    (frequencies, mean_videos) = read_light_level_videos(recordings_dir, experiment_filename, light_level, parse_mean_video)

    # Assert we read in some videos
    assert len(mean_videos) != 0 

    # Assert all of the videos are grayscale 
    assert all(len(vid.shape) < 3 for vid in mean_videos)
    
    # Create axis for all of the frequencies to fit
    total_axes = len(frequencies)+1
    fig, axes = plt.subplots(total_axes, figsize=(18,16))
    
    amplitudes = []
    for ind, (frequency, mean_video) in enumerate(zip(frequencies, mean_videos)):
        print(f"Fitting Source vs Observed Modulation: {light_level}NDF {frequency}hz")

        # Fit the source modulation to the observed for this frequency, 
        # and find the amplitude
        observed_amplitude, observed_phase = fit_source_modulation(mean_video, light_level, frequency, axes[ind])
        
        # Append this amplitude to the running list
        amplitudes.append(observed_amplitude)

    # Convert amplitudes to standardized np.array
    amplitudes = np.array(amplitudes, dtype=np.float64)

    # Plot the TTF for one light level
    ax = axes[-1]
    ax.plot(np.log10(frequencies), amplitudes, linestyle='-', marker='o', label='Observed Device')
    ax.set_ylim(bottom=0)
    ax.set_xlabel('Frequency [log]')
    ax.set_ylabel('Amplitude')
    ax.set_title(f'Amplitude by Frequency [log] {light_level}NDF')
    ax.legend()
    plt.subplots_adjust(hspace=2)

    # Save the figure
    plt.savefig(f'/Users/zacharykelly/Aguirre-Brainard Lab Dropbox/Zachary Kelly/FLIC_admin/Equipment/SpectacleCamera/calibration/graphs/TemporalSensitivity{light_level}NDF.png')
    
    # Close the plot and clear the canvas
    plt.close(fig)

    return frequencies, amplitudes

"""Generate a TTF plot for several light levels"""
def generate_TTF(recordings_dir: str, experiment_filename: str, light_levels: tuple, save_dir: str): 
    # Create a mapping between light levels and their (frequencies, amplitudes)
    light_level_ts_map: dict = {str2ndf(light_level): analyze_temporal_sensitivity(recordings_dir, experiment_filename, light_level)
                                for light_level in light_levels}
    
    # Create a plot to measure data
    fig, (ax0, ax1) = plt.subplots(1,2, figsize=(10,8))
    
    # Plot the light levels' amplitudes by frequencies
    for light_level, (frequencies, amplitudes) in light_level_ts_map.items():   
        ax0.plot(np.log10(frequencies), amplitudes, linestyle='-', marker='o', label=f"{light_level}NDF_Obs")


    # Retrieve the ideal device curve from MATLAB
    eng = matlab.engine.start_matlab() 
    sourceFreqsHz = matlab.double(np.logspace(0,2,))
    dTsignal = 1/CAM_FPS
    ideal_device_curve = np.array(eng.idealDiscreteSampleFilter(sourceFreqsHz, dTsignal)).flatten() * 0.5
    
    # Add the ideal device to the plot
    ax0.plot(np.log10(sourceFreqsHz).flatten(), ideal_device_curve, linestyle='-', marker='o', label=f"Ideal Device")

    eng.quit()

    ax0.set_xlabel("Frequency [log]")
    ax0.set_ylabel("Amplitude")
    ax0.set_title("Camera TTF Plot")
    ax0.legend()

    # Save the figure
    plt.savefig('/Users/zacharykelly/Aguirre-Brainard Lab Dropbox/Zachary Kelly/FLIC_admin/Equipment/SpectacleCamera/calibration/graphs/CameraTemporalSensitivity.png')
    
    plt.show()

"""Generate a plot of phase by row"""
def generate_row_phase_plot(video: np.array, frequency: float):
    # Start the MATLAB engine
    eng = matlab.engine.start_matlab()

    # Convert frequency to MATLAB datatype
    frequency_as_double: matlab.double = matlab.double(frequency)

    phases: list = []
    # Calculate the phase for each row of the video 
    for r in range(video.shape[1]):
        # Get the mean video of just this row
        row_video: np.array = np.mean(np.ascontiguousarray(video[:,r,:].astype(np.float64)), axis=1).flatten()

        print(f"Row_video shape {row_video.shape}")

        # Convert the row video to MATLAB type
        signal_as_double = matlab.double(row_video)

        # Find the phase
        observed_r2, observed_amplitude, observed_phase, observed_fit, observed_model_T, observed_signal_T = eng.fourierRegression(signal_as_double, frequency_as_double, CAM_FPS, nargout=6)
        
        # Append the phase to the storage container
        phases.append(observed_phase)

    # Convert the list of phases to standardized np.array
    phases = np.array(phases)

    # Plot the phases by row
    plt.plot(range(video.shape[1]), phases)
    plt.title('Phase by Row Number')
    plt.xlabel('Row Number')
    plt.ylabel('Phase')
    plt.show()

def main():    
    #recordings_dir, experiment_filename, low_bound_ndf, high_bound_ndf, save_path = parse_args()

    #analyze_temporal_sensitivity(recordings_dir, experiment_filename, high_bound_ndf)
    recordings_dir = '/Users/zacharykelly/Aguirre-Brainard Lab Dropbox/Zachary Kelly/FLIC_data/recordings'
    experiment_filename = '200FPS'
    save_path = './test'

    generate_TTF(recordings_dir, experiment_filename, ['0','1','2','3'], save_path)

if(__name__ == '__main__'):
    main()
