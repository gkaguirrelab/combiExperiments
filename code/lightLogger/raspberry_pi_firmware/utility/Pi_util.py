import os 
import re
import numpy as np
from natsort import natsorted
import pickle
import pathlib
import sys

# Import the MS utility library 
light_logger_dir_path: str = str(pathlib.Path(__file__).parents[2]) 
MS_recorder_path: str = os.path.join(light_logger_dir_path, 'miniSpect')
sys.path.append(MS_recorder_path)
import MS_util


"""Parse chunks that are stored in .pkl format, instead of broken down 
   into folders and cleanly stored"""
def parse_chunks_pkl(experiment_path: str, use_mean_frame: bool=False) -> list:

    # First, define some helper functions
    """Parser for the raw World data per chunk"""
    def world_parser(val_tuple: tuple) -> dict:
        print(f'Length of world vals: {len(val_tuple)}')

        # First value is always the frame buffer for this chunk 
        frame_buffer: np.ndarray = val_tuple[0].astype(np.uint8)

        # Third and Fourth values are always the num_captured_frames and observed FPS 
        num_captured_frames, observed_fps = val_tuple[2:]

        # Splice only the captured frames from the buffer 
        frame_buffer = frame_buffer[:num_captured_frames]
        
        #If we want to only use the mean of each frame, not the entire frame
        if(use_mean_frame):
            frame_buffer = np.mean(frame_buffer, axis=(1,2))

        # Second value is always the settings buffer for this chunk
        # The settings are in the format [duration, FPS gain, exposure]
        settings_buffer: np.ndarray = val_tuple[1].astype(np.float64)

        # Now splice only the captured frames from the settings buffer 
        settings_buffer = settings_buffer[:num_captured_frames]
 
        print(f'Frame Buffer Shape: {frame_buffer.shape}')
        print(f'Captured Frames: {num_captured_frames} | FPS: {observed_fps}')
                                     
                                                                                     # Make this a float for MATLAB use later
        return {'frame_buffer': frame_buffer, 'settings_buffer': settings_buffer, 'num_frames_captured': float(num_captured_frames), 'FPS': observed_fps}

    """Parser for the raw Pupil data per chunk"""
    def pupil_parser(val_tuple: tuple) -> dict:
        print(f'Length of Pupil vals: {len(val_tuple)}')

        # First value is always the frame buffer for this chunk
        frame_buffer: np.ndarray = val_tuple[0].astype(np.uint8)

        # Second value and third value are always num_captured_frames and observed FPS
        num_captured_frames, observed_fps = val_tuple[1:]

        # Splice out only the frames we captured from the buffer 
        frame_buffer = frame_buffer[:num_captured_frames]
        
        # If we want to only use the mean of each frame, not the entire frame
        if(use_mean_frame):
            frame_buffer = np.mean(frame_buffer, axis=(1,2))

        print(f'Frame Buffer Shape: {frame_buffer.shape}')
        print(f'Captured Frames: {num_captured_frames} | FPS: {observed_fps}')
         
                                                # Make this a float for MATLAB use later
        return {'frame_buffer': frame_buffer, 'num_frames_captured': float(num_captured_frames), 'FPS': observed_fps}

    """Parser for the raw MS data per chunk"""
    def ms_parser(val_tuple: tuple) -> dict:    
        print(f'Length of MS Vals: {len(val_tuple)}')
        
        # First value is always the unparsed byte buffer 
        bytes_buffer: bytearray = val_tuple[0]

        # Second and third values are always the num_captured_frames and observed FPS
        num_captured_frames, observed_fps = val_tuple[1:]

        print(f'Reading Buffer Shape Before: {len(bytes_buffer)} | Num readings: {len(bytes_buffer)/MS_util.MSG_LENGTH}')

        # Splice out only the frames we captured 
        bytes_buffer: bytearray = bytes_buffer[:num_captured_frames * MS_util.MSG_LENGTH]

        print(f'Reading Buffer Shape After: {len(bytes_buffer)} | Num readings: {len(bytes_buffer)/MS_util.MSG_LENGTH}')

        # Use the MS util parsing library to unpack these bytes
        AS_channels, TS_channels, LS_channels, LS_temp = MS_util.parse_readings(bytes_buffer)
   
        print(f'Captured Frames: {num_captured_frames} | FPS: {observed_fps}')

        return {name: readings_df for readings_df, name in zip((AS_channels, TS_channels, LS_channels, LS_temp), ('A', 'T', 'L', 'c'))} | {'num_frames_captured': float(num_captured_frames), 'FPS':observed_fps}

    # Define a dictionary of sensor initials and their respective parsers 
    sensor_parsers: dict = {'W': world_parser, 
                            'P': pupil_parser,
                            'M': ms_parser}

    # First, we must find the gather the sorted paths to the chunks
    # which are stored in .pkl files
    chunk_paths: list = natsorted([os.path.join(experiment_path, file) 
                                    for file in os.listdir(experiment_path)
                                    if '.pkl' in file])

    # Initialize a list to hold the sorted chunks after 
    # they have been loaded in
    sorted_chunks: list = []

    # Next, we will iterate over the chunk files and load them in 
    for chunk_num, path in enumerate(chunk_paths):
        print(f'Loading chunk: {chunk_num+1}/{len(chunk_paths)}')

        # Read in the file and append it to the sorted chunks 
        # list
        with open(path, 'rb') as f:
            # Read in the dictionary of values from this chunk
            chunk_dict: dict = pickle.load(f)

            # Append it to the sorted chunk list 
            sorted_chunks.append(chunk_dict)

    # Next, we will iterate over the chunks and their sensors and their respective data in the chunk and parse them 
    parsed_chunks: list = []
    for chunk_num, chunk in enumerate(sorted_chunks):
        print(f'Parsing chunk: {chunk_num+1}/{len(sorted_chunks)}')
        # initialize a new dictionary to hold sensors' parsed information
        parsed_chunk: dict = {}

        for key, val in chunk.items():
            # Parse this sensor's data with its appropriate sensor
            parsed_data: dict = sensor_parsers[key](val)

            # Note this sensor's parsed info for this chunk 
            parsed_chunk[key] = parsed_data
        
        # Append this parsed chunk to the growing list of parsed chunks 
        parsed_chunks.append(parsed_chunk)


    return parsed_chunks


"""Function for filtering out BAD chunks (dropped frames and thus poor fit)
   from a recording. Given """
def filter_good_chunks(fps_measured: np.ndarray, frames_captured: np.ndarray) -> np.ndarray:
    raise NotImplementedError


"""Group chunks' information together from a recording file and return them 
   as a list of tuples"""
def parse_chunks_paths(experiment_path: str) -> list:
    # Define a container for the sorted chunks 
    sorted_chunks: list = []

    # Find all of the names in the experiment path 
    experiment_files: list = os.listdir(experiment_path)

    # Find all of the bursts in sorted order
    burst_names: list = natsorted(set([re.search(r'burst\d+', file).group() 
                                      for file in experiment_files
                                      if 'burst' in file]))

    # Iterate over the burst names and build the filepaths
    # all of a given burst's readings
    for burst_idx, burst_name in enumerate(burst_names):
        # Initialize an empty dictionary for all sensors
        chunk_dict: dict = {name: ""
                           for name in ('MS', 'Pupil', 'World', 'Sunglasses', 'WorldSettings', 'WorldFPS')}
        
        # Find all of the files of this burst
        burst_files: list = (os.path.join(experiment_path, file)
                             for file in experiment_files
                             if f'_{burst_name}_' in file)
        
        # Next, we will assign the files to their respective sensors
        for file in burst_files:
            # Append world sensor directory to that category 
            if('world' in os.path.basename(file).lower() and os.path.isdir(file)):
                chunk_dict['World'] = file

            # Append the world sensor's settings file to the category
            elif('_settingshistory' in os.path.basename(file).lower() and not os.path.isdir(file)):
                chunk_dict['WorldSettings'] = file 
            
            # Append the world's FPS tracking information to that category
            elif('_fps' in os.path.basename(file).lower() and not os.path.isdir(file)):
                chunk_dict['WorldFPS'] = file
            
            # Append MS sensor files to that category
            elif('ms_readings' in os.path.basename(file).lower() and os.path.isdir(file)):
                chunk_dict['MS'] = file
            
            # Append pupil sensor files to that category
            elif('pupil' in os.path.basename(file).lower() and os.path.isdir(file)):
                chunk_dict['Pupil'] = file
            
            # Append sunglasses sensor files to that category
            elif('sunglasses' in os.path.basename(file).lower() and not os.path.isdir(file )):
                 chunk_dict['Sunglasses'] = file

        # Append this chunks' readings to the growing list
        sorted_chunks.append(chunk_dict)

    return sorted_chunks

def main():
    pass  

if(__name__ == '__main__'):
    pass