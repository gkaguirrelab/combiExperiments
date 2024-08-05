#from picamera2 import Picamera2, Preview
import time
import cv2
import matplotlib.pyplot as plt
import numpy as np
import os
import re
from scipy.io import savemat
import argparse 

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

def plot_intensity_over_time(video: list):
    frame_avgs = [np.mean(frame, axis=(0,1)) for frame in video]
    plt.plot(range(0, len(frame_avgs), frame_avgs))
    plt.show()

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
def parse_video(path_to_video: str) -> np.array:
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
    return frames[:,:,:,0]


"""Analyze the temporal sensitivity of the camera, showing
   fit of source modulation to observed and TS plot across frequencies"""
def analyze_temporal_sensitivity(recordings_dir: str, experiment_filename: str, light_levels: tuple, save_dir: str) -> dict:
    # Create matrix where each row i is the ith light level's videos of different freqeuncies                                                                 # Compare the text between _ and NDF in the string to the light level
    light_levels_files = [ [ os.path.join(recordings_dir, file) for file in os.listdir(recordings_dir) 
                            if experiment_filename in file and light_level == file.split('_')[-1][:-7] ] # :-7 to just select the stuff between _ and NDF
                            for light_level in light_levels ] 

    # Create a mapping between the light levels and the videos taken at different frequencies at that light level  
    light_level_videos: dict = {light_level : [ parse_video(file) for file in light_level_files ] 
                                for light_level, light_level_files in zip(light_levels, light_levels_files)}

    # Creat mapping to store the x (freq), y (amp) values for a given light level
    light_level_frequencies_amplitudes = {light_level: {"Frequencies":[], 
                                                        "Amplitudes":[]}
                                                        for light_level in light_levels + ["Ideal Device"]}

    # Iterate over the light levels
    for ind, (light_level, videos) in enumerate(light_level_videos.items()): 
        # Parse the frequency of each video at this light level         # :-2 to get rid of the hz
        frequencies: list = [ float(re.search(r'\d+[\.x]\d+hz', file).group()[:-2]) 
                             for file in light_levels_files[ind]]

        # Convert the videos to grayscale if they are not already
        grayscale_videos: np.array = np.array([ videos[i] if(len(videos[i].shape) == 3) 
                                               else np.array(cv2.cvtColor(videos[i], cv2.COLOR_BGR2GRAY)) 
                                               for i in range(len(videos)) ], dtype=np.uint8)

        # Find average intensity of every frame in every video
        average_frame_intensities: np.array = np.mean(grayscale_videos, axis=(2,3))

        # For each frequency and associated video, plot the source modulation and 
        # fit the observed values to the source modulation
        for frequency, avg_video in zip(frequencies, average_frame_intensities):
            duration: float = avg_video.shape[0] / CAM_FPS # duration of the signal in seconds 
            source_amplitude: float = np.max(avg_video) - np.mean(avg_video) 
            source_phase: int = 0

            # Generate mock source time values and sinusoidal wave 
            t_source: np.array = np.linspace(0, duration, avg_video.shape[0], endpoint=False)
            y_source: np.array = source_amplitude * np.sin(2 * np.pi * frequency * t_source + source_phase)  + np.mean(avg_video)

            # Generate x values in time for the measured points   
            t_measured: np.array = np.linspace(0, duration, avg_video.shape[0], endpoint=False)
            y_measured: np.array = avg_video

            # Apply Fourier Transform to fit the source to the observed
            source_fft = np.fft.fft(y_source)
            measured_fft = np.fft.fft(y_measured)

            # Calculate the phase difference
            phase_diff = np.angle(measured_fft) - np.angle(source_fft)

            # Correct the phase of the source signal
            corrected_fft = source_fft * np.exp(1j * phase_diff)
            fit_y_source = np.fft.ifft(corrected_fft).real

            # Store the frequency and amplitudes for this light_level + frequency
            light_level_frequencies_amplitudes[light_level]["Frequencies"] += []
            light_level_frequencies_amplitudes[light_level]["Amplitudes"] += []
            light_level_frequencies_amplitudes["Ideal Device"]["Frequencies"] += []
            light_level_frequencies_amplitudes["Ideal Device"]["Amplitudes"] += [] 

            # Plot how well measured fits to source over 
            # time
            plt.title(f"Source vs Observed Modulation {light_level}NDF {frequency}hz")
            plt.xlabel('Time (seconds)')
            plt.ylabel('Amplitude')
            plt.plot(t_source, fit_y_source, label='Source Modulation')
            plt.plot(t_measured, y_measured, label='Measured')
            plt.legend()
            plt.show()

    # Build an array container full of NaNs to hold the results 
    experiment_results_as_mat = np.full((len(light_levels), \
                                         len(light_level_frequencies_amplitudes["Ideal Device"]["Frequencies"]), \
                                         len(light_level_frequencies_amplitudes["Ideal Device"]["Amplitudes"])), \
                                         np.nan)  
    
    # Plot the temporal sensitivity across frequencies
    plt.title(f"Camera Temporal Sensitivity")
    plt.xlabel('Frequency')
    plt.ylabel('Amplitude')
    
    # Iterate over the source observers (low, high, ideal)
    for i, (source, info) in enumerate(light_level_frequencies_amplitudes.items()):
        # Retrieve their frequencies and amplitude
        frequencies, amplitudes = np.array(info["Frequencies"]), np.array(info["Amplitudes"])
        
        # Plot this observer's curve
        label = source if source == "Ideal Device" else source +' NDF'
        plt.plot(np.log10(frequencies), amplitudes, label=label)

        # Don't save the ideal device information
        if(label == "Ideal Device"): continue 
        
        # Insert this light level's frequencies and amplitudes into the .mat container 
        for j in range(frequencies.shape[0]):
            experiment_results_as_mat[i,j,:] = amplitudes

    plt.legend()
    plt.show()
    
    # Save the temporal sensitivity plot and the results as matlab file
    plt.savefig(os.path.join(save_dir, "TemporalSensitivity.png"))
    savemat(os.path.join(save_dir, "TemporalSensitivity.mat"), {"experiment_results" : experiment_results_as_mat})

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
    
    middle_pixel = np.array(frame[0].shape[0] // 2, frame[0].shape[1] // 2) 
    plot_intensity_over_time([frame[middle_pixel] for frame in frames])

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
    
    # Build the video from the frames and save it 
    reconstruct_video(frames, output_path)
    
    

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
    recordings_dir, experiment_filename, low_bound_ndf, high_bound_ndf, save_path = parse_args()

    analyze_temporal_sensitivity(recordings_dir, experiment_filename, [low_bound_ndf, high_bound_ndf], save_path)

if(__name__ == '__main__'):
    main()
