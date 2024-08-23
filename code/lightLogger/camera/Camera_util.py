import cv2
import matplotlib.pyplot as plt
import numpy as np
import os
import argparse 
import sys 
import matlab.engine
from natsort import natsorted
from collections.abc import Iterable
import pickle
import scipy.io

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
    
    # Construct the path to the metadata directory
    metadata_dir: str = recordings_dir + '_metadata'
    
    # Create container to map frequencies and their videos
    frequencies_and_videos: dict = {}

    print(f"Reading in {experiment_filename} {light_level}NDF videos...")

    # Read in all the files in the recording dir
    for file in os.listdir(recordings_dir):
        if(file == '.DS_Store'): continue
        
        # Build the complete path to the file
        filepath = os.path.join(recordings_dir, file)

        # Parse the experiment information out of the filename
        experiment_info: dict = parse_recording_filename(file)

        # If the video isn't from the target experiment, skip 
        if(experiment_info["experiment_name"] != experiment_filename):
            continue 
        
        # If the video is not from this light_level, skip 
        if(experiment_info["NDF"] != str2ndf(light_level)):
            continue 
        
        # Find the path to the warmup (0hz) file itself 
        tokens: list = os.path.splitext(file)[0].split('_') # Split based on meaningful _ character 

        tokens[1] = '0hz' # set frequency part equal to 0hz 
        warmup_settings_filename: str = '_'.join(tokens) + '_warmup_settingsHistory.pkl' # construct the warmup_settings filename
        warmup_settings_filepath: str = os.path.join(metadata_dir, warmup_settings_filename) # append it to the metadata dir path 
        
        # Find the path to the settings file for the video
        video_settings_filepath: str = os.path.join(metadata_dir, os.path.splitext(file)[0] + '_settingsHistory.pkl')
        
        # Parse the video and pair it with its frequency 
        print(f"Reading {light_level}NDF {experiment_info['frequency']}hz from {file}")
        print(f'Warmup settings from: {os.path.basename(warmup_settings_filepath)}')
        print(f'Video settings from: {os.path.basename(video_settings_filepath)}')

        # Read in the gain + exposure settings of the camera 
        warmup_settings: dict = None 
        video_settings : dict = None 

        with open(warmup_settings_filepath, 'rb') as f:
            warmup_settings = pickle.load(f)
        
        with open(video_settings_filepath, 'rb') as f:
            video_settings = pickle.load(f)

        # Associate the frequency to this tuple of (video, warmup_settings, settings)
        frequencies_and_videos[experiment_info["frequency"]] = (parser(filepath), warmup_settings, video_settings)

    # Sort the videos by their frequencies
    sorted_by_frequencies: list = sorted(frequencies_and_videos.items())

    # Split the two back into seperate lists
    frequencies: list = []
    videos: list = []
    warmup_settings_list: list = []
    video_settings_list: list = []
    for (frequency, (video, warmup_settings, video_settings)) in sorted_by_frequencies:
        frequencies.append(frequency)
        videos.append(video)
        warmup_settings_list.append(warmup_settings)
        video_settings_list.append(video_settings)

    return np.array(frequencies, dtype=np.float64), videos, warmup_settings_list, video_settings_list

"""Fit the source modulation to the observed and plot the fit"""
def fit_source_modulation(signal: np.array, light_level: str, frequency: float, ax: plt.Axes=None, fps_guess: float=CAM_FPS, fps_guess_increment: tuple=(0,0.25)) -> tuple:     
    # Start the MATLAB engine
    eng = matlab.engine.start_matlab()

    # Ensure MATLAB started properly
    assert eng is not None
    
    # Convert signal to contrast
    signal_mean = np.mean(signal)
    signal = (signal - signal_mean) / signal_mean

    # Find the actual FPS of the observed data (might be slightly different than our guess)
    observed_fps: matlab.double = eng.findObservedFPS(matlab.double(signal), 
                                                      matlab.double(frequency), 
                                                      matlab.double([fps_guess+fps_guess_increment[0], fps_guess+fps_guess_increment[1]]), 
                                                      nargout=1)
    
    # Fit the data
    observed_r2, observed_amplitude, observed_phase, observed_fit, observed_model_T, observed_signal_T = eng.fourierRegression(matlab.double(signal), 
                                                                                                                               matlab.double(frequency), 
                                                                                                                               observed_fps, 
                                                                                                                               nargout=6)
    print(f"Observed FPS: {observed_fps}")
    print(f"R2: {observed_r2}")
    print(f"Amplitude: {observed_amplitude}")

    # Close the MATLAB engine 
    eng.quit()
    
    # Convert returned data back to Python datatype 
    observed_signal_T: np.array = np.array(observed_signal_T).flatten()
    observed_model_T: np.array = np.array(observed_model_T).flatten()
    observed_fit: np.array = np.array(observed_fit).flatten()

    # If we do not want to plot, simply return
    if(ax is None):
        return observed_amplitude, observed_phase, observed_fps

    # Plot the fit on a given axis 
    ax.plot(observed_signal_T, signal-np.mean(signal), linestyle='-', label="Measured")
    ax.plot(observed_model_T, observed_fit, linestyle='-', label="Fit")
    ax.legend(fontsize=4)
    ax.set_title(f"Measured vs Fit Modulation {light_level}NDF {frequency}hz")
    ax.set_xlabel('Time [seconds]')
    ax.set_ylabel('Contrast')
    ax.set_ylim((-0.5, 0.5))

    return observed_amplitude, observed_phase, observed_fps

"""Analyze the temporal sensitivity of a given light level, fit source vs observed for all frequencies"""
def analyze_temporal_sensitivity(recordings_dir: str, experiment_filename: str, light_level: str) -> tuple:
    print(f"Generating TTF : {light_level}NDF")

    # Make another document for just the warmup values per NDF

    # Read in the videos at different frequencies 
    (frequencies, mean_videos, warmup_settings, video_settings) = read_light_level_videos(recordings_dir, experiment_filename, light_level, parse_mean_video)

    # Assert we read in some videos
    assert len(mean_videos) != 0 

    # Assert all of the videos are grayscale 
    assert all(len(vid.shape) < 3 for vid in mean_videos)
    
    # Create axis for all of the frequencies to fit
    total_axes = len(frequencies)+1 # frequencies + 1 for the TTF 
    moldulation_fig, modulation_axes = plt.subplots(total_axes, figsize=(18,16))
    settings_fig, settings_axes = plt.subplots(total_axes-1, figsize=(18,16))
    
    # Ensure the settings are an iterable format
    settings_axes = settings_axes if isinstance(settings_axes, Iterable) else [settings_axes]

    # Find the amplitude and FPS of the videos
    amplitudes, videos_fps = [], []
    for ind, (frequency, mean_video, warmup_settings_history, video_settings_history) in enumerate(zip(frequencies, mean_videos, warmup_settings, video_settings)):
        print(f"Fitting Source vs Observed Modulation: {light_level}NDF {frequency}hz")
        moduation_axis, gain_axis = modulation_axes[ind], settings_axes[ind]

        # Fit the source modulation to the observed for this frequency, 
        # and find the amplitude
        observed_amplitude, observed_phase, observed_fps = fit_source_modulation(mean_video, light_level, frequency, moduation_axis)

        # Build the temporal support of the settings values by converting frame num to second
        #warmup_t: np.array = np.arange(0, warmup_settings_history['gain_history'].shape[0]/observed_fps, 1/observed_fps)
        settings_t: np.array = np.arange(0, mean_video.shape[0]/observed_fps, 1/observed_fps)
        
        # Because we are counting by float, sometimes the shapes are off by a frame, so just 
        # take how many points we actually have 
        num_video_points = len(video_settings_history['gain_history'])
        settings_t = settings_t[:num_video_points]

        # Plot the gain of the camera over the course of the modulation video
        gain_axis.plot(settings_t, video_settings_history['gain_history'], color='red', label='Gain') 
        gain_axis.set_title(f'Camera Settings {light_level}NDF {frequency}hz')
        gain_axis.set_xlabel('Time [seconds]')
        gain_axis.set_ylabel('Gain', color='red')
        
        # Plot the exposure of the camera over the course of the modulation video on the same plot
        # but with a different axis
        exposure_axis = gain_axis.twinx()
        exposure_axis.plot(settings_t, video_settings_history['exposure_history'], color='orange', label='Exposure Time')
        exposure_axis.set_ylabel('Exposure', color='orange')

        # Append this amplitude to the running list
        amplitudes.append(observed_amplitude)
        videos_fps.append(observed_fps)

    # Convert amplitudes to standardized np.array
    amplitudes = np.array(amplitudes, dtype=np.float64)
    videos_fps = np.array(videos_fps, dtype=np.float32)

    # Plot the TTF for one light level
    ax = modulation_axes[-1]
    ax.plot(np.log10(frequencies), amplitudes, linestyle='-', marker='o', label='Observed Device')
    ax.set_ylim(bottom=0)
    ax.set_xlabel('Frequency [log]')
    ax.set_ylabel('Amplitude')
    ax.set_title(f'Amplitude by Frequency [log] {light_level}NDF')
    ax.legend()
    
    # Adjust the spacing between the plots
    moldulation_fig.subplots_adjust(hspace=2)
    settings_fig.subplots_adjust(hspace=2)

    # Save the figure
    moldulation_fig.savefig(f'/Users/zacharykelly/Aguirre-Brainard Lab Dropbox/Zachary Kelly/FLIC_admin/Equipment/SpectacleCamera/calibration/graphs/TemporalSensitivity{light_level}NDF.pdf')
    settings_fig.savefig(f'/Users/zacharykelly/Aguirre-Brainard Lab Dropbox/Zachary Kelly/FLIC_admin/Equipment/SpectacleCamera/calibration/graphs/cameraSettings{light_level}NDF.pdf')

    # Close the plot and clear the canvas
    plt.close(moldulation_fig)
    plt.close(settings_fig)

    return frequencies, amplitudes, videos_fps, warmup_settings

"Plot the TTF of the Klein at a single light level"
def generate_klein_ttf(recordings_dir: str, experiment_filename: str):
    videos = [ (file, scipy.io.loadmat(os.path.join(recordings_dir, file))) 
              for file in os.listdir(recordings_dir)
              if experiment_filename == file.split('_')[0]]
    
    fig, axes = plt.subplots(len(videos),1)
    results = {}
    for ind, (filename, mat) in enumerate(videos):
        name, extension = os.path.splitext(filename)

        filename = name + f'_0NDF{extension}'

        print(f"Analyzing {filename}")

        file_info = parse_recording_filename(filename)

        light_level = file_info['NDF']
        f = file_info['frequency']
        video = mat['luminance256HzData'][0].flatten().astype(np.float64)

        observed_amplitude, observed_phase, observed_fps = fit_source_modulation(video, light_level, f, ax=axes[ind], fps_guess=256)

        results[f] = [observed_amplitude, observed_fps]

    fig.show()

    eng = matlab.engine.start_matlab() 
    eng.addpath('/Users/zacharykelly/Documents/MATLAB/toolboxes/combiLEDToolbox/code/calibration/measureFlickerRolloff/')

    # Sort the results by frequency
    sorted_by_frequency = sorted(results.items())
    frequencies = []
    amplitudes = []

    for (frequency, (amplitude, fps)) in sorted_by_frequency:
        frequencies.append(frequency)
        amplitudes.append(amplitude)

    frequencies = np.array(frequencies, dtype=np.float64)
    amplitudes = np.array(amplitudes)
    expected_amplitudes = np.array(eng.contrastAttenuationByFreq(matlab.double([6,12,25,50]))).flatten()*0.5


    plt.plot(np.log10(frequencies), amplitudes, marker='.')
    plt.plot(np.log10([6,12,25,50]),[0.5,0.4965,0.4715,0.4175], marker='x', color='red')
    plt.plot(np.log10([6,12,25,50]), expected_amplitudes, marker='o', color='green')
    plt.xlabel('Frequency [log]')
    plt.ylabel('Amplitude')
    plt.title('Klein TTF Plot (0 NDF)')
    plt.show()


"""Generate a TTF plot for several light levels"""
def generate_TTF(recordings_dir: str, experiment_filename: str, light_levels: tuple): 
    # Create a mapping between light levels and their (frequencies, amplitudes)
    light_level_ts_map: dict = {str2ndf(light_level): analyze_temporal_sensitivity(recordings_dir, experiment_filename, light_level)
                                                      for light_level in light_levels}
    
    # Create a TTF plot to measure data
    ttf_fig, (ttf_ax0, ttf_ax1) = plt.subplots(1, 2, figsize=(10,8))

    # Create a plot to measure warmup times per light-level
    warmup_fig, warmup_axes = plt.subplots(len(light_level_ts_map), 1, figsize=(10,8))

    # Ensure warmup_axes is an iterable object
    warmup_axes = warmup_axes if isinstance(warmup_axes, Iterable) else [warmup_axes]
    
    # Plot the light levels' amplitudes by frequencies
    for ind, (light_level, (frequencies, amplitudes, videos_fps, warmup_settings)) in enumerate(light_level_ts_map.items()):      
        # Plot the amplitude and FPS
        ttf_ax0.plot(np.log10(frequencies), amplitudes, linestyle='-', marker='o', label=f"{light_level}NDF")
        ttf_ax1.plot(np.log10(frequencies), videos_fps, linestyle='-', marker='o', label=f"{light_level}NDF FPS")
        
        # Retrieve info to plot the camera settings over the warmup period
        gain_axis = warmup_axes[ind]
        gain_history: np.array = warmup_settings[0]['gain_history']
        exposure_history: np.array = warmup_settings[0]['exposure_history']
        warmup_t: np.array = np.arange(0, len(gain_history)/CAM_FPS, 1/CAM_FPS)

        # Plot the gain of the camera over the course of the warmup video
        gain_axis.plot(warmup_t, gain_history, color='red', label='Gain') 
        gain_axis.set_title(f'Camera Settings {light_level}NDF {frequencies[0]}hz')
        gain_axis.set_xlabel('Time [seconds]')
        gain_axis.set_ylabel('Gain', color='red')
        gain_axis.set_ylim([0.5,11])
        
        # Plot the exposure of the camera over the course of the warmup video on the same plot
        # but with a different axis
        exposure_axis = gain_axis.twinx()
        exposure_axis.plot(warmup_t, exposure_history, color='orange', label='Exposure Time')
        exposure_axis.set_ylabel('Exposure', color='orange')
        exposure_axis.set_ylim([35,5000])

    # Retrieve the ideal device curve from MATLAB
    eng = matlab.engine.start_matlab() 
    sourceFreqsHz = matlab.double(np.logspace(0,2,))
    dTsignal = 1/CAM_FPS
    ideal_device_curve = np.array(eng.idealDiscreteSampleFilter(sourceFreqsHz, dTsignal)).flatten() * 0.5
    
    # Add the ideal device to the plot
    ttf_ax0.plot(np.log10(sourceFreqsHz).flatten(), ideal_device_curve, linestyle='-', marker='o', label=f"Ideal Device")

    # Close the MATLAB engine 
    eng.quit()

    # Label TTF and FPS plot
    ttf_ax0.set_xlabel("Frequency [log]")
    ttf_ax0.set_ylabel("Amplitude")
    ttf_ax0.set_title("Camera TTF Plot")
    ttf_ax0.legend()

    ttf_ax1.set_xlabel("Frequency [log]")
    ttf_ax1.set_ylabel("FPS")
    ttf_ax1.set_title("FPS by Frequency/Light Level")
    ttf_ax1.legend()

    # Adjust spacing between subplots
    ttf_fig.subplots_adjust(hspace=2)
    warmup_fig.subplots_adjust(hspace=2)

    # Save the figure
    ttf_fig.savefig('/Users/zacharykelly/Aguirre-Brainard Lab Dropbox/Zachary Kelly/FLIC_admin/Equipment/SpectacleCamera/calibration/graphs/CameraTemporalSensitivity.pdf')
    warmup_fig.savefig('/Users/zacharykelly/Aguirre-Brainard Lab Dropbox/Zachary Kelly/FLIC_admin/Equipment/SpectacleCamera/calibration/graphs/warmupSettings.pdf')
    
    plt.show()

"""Generate a plot of mean microseconds per line by categorical exposure time"""
def generate_ms_by_exposure_plot(recordings_dir: str, light_levels: list):
    # Define containers used for plotting
    x: list = []
    y: list = []
    yerr: list = []

    # Iterate across light levels
    for light_level in light_levels:
        # Define frequencies to conduct plotting for
        # and container for per-view results
        frequencies_to_test: set = {6, 12, 25}
        microseconds_per_row_list: list = []

        # Retrieve the videos by finding videos whose light level matches and whose frequencies are 
        # in the set of frequencies to test
        print(f"Retreiving {light_level} videos")
        videos = [(os.path.join(recordings_dir, file), parse_video(os.path.join(recordings_dir, file))) 
                  for file in os.listdir(recordings_dir) 
                  if f"{light_level}NDF" in file 
                  and parse_recording_filename(file)['frequency'] in frequencies_to_test]

        # Find the slope and associated microseconds per row of each video
        for (path, video) in videos:
            print(f'Plotting row phase for {path}')
            
            # Find the frequency for this video
            f = parse_recording_filename(os.path.split(path)[1])['frequency']

            # Calculate relevant information
            slope = generate_row_phase_plot(video, f)
            secs_per_row = slope/(2*np.pi*f)
            microseconds_per_row_list.append(abs(secs_per_row*1000000))

        # Convert list to standardized np.array
        microseconds_per_row_list: np.array = np.array(microseconds_per_row_list)
        
        # Calculate values for this light level (exposure time is categorical here since it maxes at anything below 0)
        exposure_time = 1 if light_level == '0' else 2
        mean_microseconds_per_row = np.mean(microseconds_per_row_list)
        std_microseconds_per_row = np.std(microseconds_per_row_list)

        print(f"Exposure Time: {exposure_time}")
        print(f"Mean Microseconds: {mean_microseconds_per_row}")
        print(f"Std microseconds per row: {std_microseconds_per_row}")

        # Append values to the plotting containers
        x.append(exposure_time)
        y.append(mean_microseconds_per_row)
        yerr.append(std_microseconds_per_row)

    # Plot the data
    plt.errorbar(x, y, yerr=yerr, linestyle='', marker='o', color='blue', ecolor='red')
    plt.title('Mean Microseconds per Row by Exposure')
    plt.xlabel('Exposure Time')
    plt.ylabel('Mean Microseconds per Row')
    plt.show()


"""Generate a plot of phase by row"""
def generate_row_phase_plot(video: np.array, frequency: float) -> float:
    # Start the MATLAB engine
    eng = matlab.engine.start_matlab()

    # Calculate the phase for each row of the video 
    phases: list = []
    for r in range(video.shape[1]):
        # Get the mean video of just this row
        row_video: np.array = np.mean(np.ascontiguousarray(video[:,r,:].astype(np.float64)), axis=1).flatten()

        #print(f"Row_video shape {row_video.shape}")

        # Find the phase
        observed_r2, observed_amplitude, observed_phase, observed_fit, observed_model_T, observed_signal_T = eng.fourierRegression(matlab.double(row_video),
                                                                                                                                   matlab.double(frequency), 
                                                                                                                                   matlab.double(CAM_FPS), 
                                                                                                                                   nargout=6)
        
        # Append the phase to the storage container
        phases.append(observed_phase)

    # Convert the list of phases to standardized np.array
    phases = np.unwrap(np.array(phases), period=np.pi/4)

    x, y = range(video.shape[1]), phases

    # Fit a linear polynomial (degree 1)
    coefficients: list = np.polyfit(x, y, 1)
    slope: float = coefficients[0]

    # Plot the phases by row
    plt.plot(x, y)
    plt.title('Phase by Row Number')
    plt.xlabel('Row Number')
    plt.ylabel('Phase')
    plt.show()

    return slope




def main():    
    #recordings_dir, experiment_filename, low_bound_ndf, high_bound_ndf, save_path = parse_args()

    #analyze_temporal_sensitivity(recordings_dir, experiment_filename, high_bound_ndf)
    recordings_dir = '/Users/zacharykelly/Aguirre-Brainard Lab Dropbox/Zachary Kelly/FLIC_data/recordings'
    experiment_filename = '200FPS'
    save_path = './test'

    generate_TTF(recordings_dir, experiment_filename, ['0','1','2','3'])

if(__name__ == '__main__'):
    main()
