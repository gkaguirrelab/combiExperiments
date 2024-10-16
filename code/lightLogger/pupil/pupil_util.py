import numpy as np
import pandas as pd
import os
import pathlib
import sys
from recorder import CAM_FPS
import matplotlib.pyplot as plt
import matlab

# Import the world camera util library (as we will reuse some functions directly from it)
world_cam_util_path: str = os.path.join(pathlib.Path(__file__).parents[1], 'camera')
sys.path.append(world_cam_util_path)
import Camera_util

"""Read all videos in of a certain light level"""
def read_light_level_videos(recordings_dir: str, experiment_filename: str, 
                            light_level: str, parser: object) -> tuple:
    
    # Create container to map frequencies and their videos
    frequencies_and_videos: dict = {}

    print(f"Reading in {experiment_filename} {light_level}NDF videos...")

    # Read in all the files in the recording dir
    for file in os.listdir(recordings_dir):
        if(file == '.DS_Store'): continue
        
        # Build the complete path to the file
        filepath = os.path.join(recordings_dir, file)

        # Parse the experiment information out of the filename
        experiment_info: dict = Camera_util.parse_recording_filename(file)

        # If the video isn't from the target experiment, skip 
        if(experiment_info["experiment_name"] != experiment_filename):
            continue 
        
        # If the video is not from this light_level, skip 
        if(experiment_info["NDF"] != Camera_util.str2ndf(light_level)):
            continue 

        # Associate the frequency to this video
        frequencies_and_videos[experiment_info["frequency"]] = parser(filepath)

    # Sort the videos by their frequencies
    sorted_by_frequencies: list = sorted(frequencies_and_videos.items())

    # Split the two back into seperate lists
    frequencies: list = []
    videos: list = []
    for (frequency, (video)) in sorted_by_frequencies:
        frequencies.append(frequency)
        videos.append(video)

    return np.array(frequencies, dtype=np.float64), videos

"""Analyze the temporal sensitivity of a given light level, fit source vs observed for all frequencies"""
def analyze_temporal_sensitivity(recordings_dir: str, experiment_filename: str, light_level: str) -> tuple:
    print(f"Generating TTF : {light_level}NDF")

    # Read in the videos at different frequencies 
    (frequencies, mean_videos) = read_light_level_videos(recordings_dir, experiment_filename, light_level, Camera_util.parse_mean_video)

    # Assert we read in some videos
    assert len(mean_videos) != 0 

    # Assert all of the videos are grayscale 
    assert all(len(vid.shape) < 3 for vid in mean_videos)
    
    # Create axis for all of the frequencies to fit
    total_axes = len(frequencies)+1 # frequencies + 1 for the TTF 
    moldulation_fig, modulation_axes = plt.subplots(total_axes, figsize=(18,16))

    # Find the amplitude and FPS of the videos
    amplitudes, videos_fps, fits = [], [], []
    for ind, (frequency, mean_video) in enumerate(zip(frequencies, mean_videos)):
        print(f"Fitting Source vs Observed Modulation: {light_level}NDF {frequency}hz")
        moduation_axis = modulation_axes[ind]

        # Fit the source modulation to the observed for this frequency, 
        # and find the amplitude                                                                    # Exclude the warmup period of the video by only taking everything after 3 seconds
        observed_amplitude, observed_phase, observed_fps, fit = Camera_util.fit_source_modulation(mean_video[3*CAM_FPS:], light_level, frequency, moduation_axis, fps_guess=CAM_FPS, fps_guess_increment=(-10,10))

        # Append this information to the running lists
        amplitudes.append(observed_amplitude)
        videos_fps.append(observed_fps)
        fits.append(fit)


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

    # Save the figure
    moldulation_fig.savefig(f'/Users/zacharykelly/Aguirre-Brainard Lab Dropbox/Zachary Kelly/FLIC_admin/Equipment/pupilCamera/calibration/graphs/MeasuredVSFitModulations{light_level}NDF.pdf')

    # Close the plot and clear the canvas
    plt.close(moldulation_fig)

    return frequencies, amplitudes, videos_fps, fits

"""Generate a TTF plot for several light levels, return values used to generate the plot"""
def generate_TTF(recordings_dir: str, experiment_filename: str, light_levels: tuple, save_path: str=None, hold_figures_on: bool=False) -> dict: 
    # Start the MATLAB engine
    eng = matlab.engine.start_matlab()
    eng.addpath('~/Documents/MATLAB/toolboxes/combiLEDToolbox/code/calibration/measureFlickerRolloff/')
    eng.addpath('~/Documents/MATLAB/projects/combiExperiments/code/lightLogger/camera')

    # Create a mapping between light levels and their (frequencies, amplitudes)
    light_level_ts_map: dict = {Camera_util.str2ndf(light_level) : analyze_temporal_sensitivity(recordings_dir, experiment_filename, light_level)
                                                       for light_level in light_levels}

    # Create a mapping of the frequencies and their verified amplitudes 
    # via the Klein chromasurf software.
    klein_frequencies_and_amplitudes: dict = {freq : amp 
                                            for freq, amp
                                            in zip([6,12,25,50,100], np.array([0.5,0.4965,0.4715,0.4175,0.31]) / 0.5)}

    # Create a TTF plot to measure data
    ttf_fig, (ttf_ax0, ttf_ax1, ttf_ax2) = plt.subplots(3, 1, figsize=(14,12))
    
    # Initialize a results container to store values used to generate the plot
    results: dict = {'fixed_FPS': CAM_FPS} 

    # Plot the light levels' amplitudes by frequencies
    for ind, (light_level, (frequencies, amplitudes, videos_fps, fits)) in enumerate(light_level_ts_map.items()):  
        # Find the corrected amplitude for these frequencies
        corrected_amplitudes: np.array = np.array([amp if freq not in klein_frequencies_and_amplitudes 
                                                    else amp / klein_frequencies_and_amplitudes[freq] 
                                                    for freq, amp 
                                                    in zip(frequencies, amplitudes)])

        # Plot the amplitude and FPS
        ttf_ax0.plot(np.log10(frequencies), amplitudes, linestyle='-', marker='o', label=f"{light_level}NDF")
        ttf_ax1.plot(np.log10(frequencies), corrected_amplitudes, linestyle='-', marker='o', label=f"{light_level}NDF")
        ttf_ax2.plot(np.log10(frequencies), videos_fps, linestyle='-', marker='o', label=f"{light_level}NDF FPS")

        # Record these results in the results dictionary
        results['ND'+str(light_level).replace('.', 'x')] = {'amplitudes': amplitudes,
                                                            'corrected_amplitudes': corrected_amplitudes,
                                                            'videos_fps': videos_fps,
                                                            'fits': {'F'+str(freq).replace('.', 'x'): fit 
                                                            for freq, fit in zip(frequencies, fits)}}

    # Retrieve the ideal device curve from MATLAB
    sourceFreqsHz = matlab.double(np.logspace(0,2))
    dTsignal = 1/CAM_FPS
    ideal_device_curve = (np.array(eng.idealDiscreteSampleFilter(sourceFreqsHz, dTsignal)).flatten() * 0.5).astype(np.float64)
    
    # Record the ideal_device_curve in the results dictionary
    results['ideal_device'] = [np.array(sourceFreqsHz, dtype=np.float64), ideal_device_curve]

    # Add the ideal device to the plot
    ttf_ax0.plot(np.log10(sourceFreqsHz).flatten(), ideal_device_curve, linestyle='-', marker='o', label=f"Ideal Device")
    ttf_ax1.plot(np.log10(sourceFreqsHz).flatten(), ideal_device_curve, linestyle='-', marker='o', label=f"Ideal Device")

    # Standardize the y axis scale
    ttf_ax0.set_ylim([0, 0.65])
    ttf_ax1.set_ylim([0, 0.65])

    # Close the MATLAB engine 
    eng.quit()

    # Label TTF and FPS plot
    ttf_ax0.set_xlabel("Frequency [log]")
    ttf_ax0.set_ylabel("Amplitude")
    ttf_ax0.set_title("Pupil Camera TTF Plot")
    ttf_ax0.legend()

    ttf_ax1.set_xlabel("Frequency [log]")
    ttf_ax1.set_ylabel("Amplitude")
    ttf_ax1.set_title("Corrected Pupil Camera TTF Plot")
    ttf_ax1.legend()

    ttf_ax2.set_xlabel("Frequency [log]")
    ttf_ax2.set_ylabel("FPS")
    ttf_ax2.set_title("FPS by Frequency/Light Level")
    ttf_ax2.legend()

    # Adjust spacing between subplots
    ttf_fig.subplots_adjust(hspace=2)
    ttf_fig.subplots_adjust(wspace=0.5)

    # Save the figure
    ttf_fig.savefig('/Users/zacharykelly/Aguirre-Brainard Lab Dropbox/Zachary Kelly/FLIC_admin/Equipment/pupilCamera/calibration/graphs/PupilCameraTemporalSensitivity.pdf')

    # Display the figure
    if(hold_figures_on is True):
        plt.show()

    # If we do not want to save the results, simply return 
    if(save_path is None):
        return results

    # Otherwise, save the results of generating the TTF plot
    with open(os.path.join(save_path,'TTF_info.pkl'), 'wb') as f:
        pickle.dump(results, f)





if(__name__ == '__main__'):
    pass