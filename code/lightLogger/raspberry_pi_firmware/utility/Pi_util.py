import os 
import re
import numpy as np
from natsort import natsorted
import pickle
import pathlib
import sys
import ctypes
import pandas as pd
import cv2
import json

# Import the MS utility library 
light_logger_dir_path: str = str(pathlib.Path(__file__).parents[2]) 
MS_recorder_path: str = os.path.join(light_logger_dir_path, 'miniSpect')
sys.path.append(MS_recorder_path)
import MS_util

"""Parse an entire recording captured with the C++ implementation of RPI firmware"""
def parse_chunks_binary(recording_dir_path: str, use_mean_frame: bool=False, start_chunk: int=0, end_chunk: int=None) -> list:
    # First, let's find all of the chunks in sorted order
    chunk_filepaths: list = [os.path.join(recording_dir_path, file)
                            for file in natsorted(os.listdir(recording_dir_path))
                            if 'chunk' in file][start_chunk:end_chunk]

    
    # Load in the performance data
    performance_json: dict = None 
    with open(os.path.join(recording_dir_path, 'performance.json'), 'r') as f:
        performance_json: dict = json.load(f)

        # Need to re-interpret the controller names as char, as they are by default 
        # read in as unsigned int 
        performance_json['controller_names'] = [chr(name) for name in performance_json['controller_names']]

    # Now, let's read in all of the chunks
    chunks: list = [parse_chunk_binary(chunk_path, performance_json, use_mean_frame=use_mean_frame)
                    for chunk_path in chunk_filepaths]

    return {"performance_dict": performance_json, 'chunks': chunks}

"""Parse an individual chunk that was captured with the C++ implementation of RPI firmware"""
def parse_chunk_binary(chunk_path: str, performance_json: dict, use_mean_frame: bool=False) -> dict:
    # Load in the CPP deserialization library
    cpp_parser_lib = ctypes.CDLL(os.path.join(os.path.dirname(__file__), "parse_chunk_binary.so"))

    # Define the return type of the CPP deserialization function
    class chunk_struct(ctypes.Structure):
        _fields_ = [
            ("M", ctypes.POINTER(ctypes.c_uint8)),
            ("W", ctypes.POINTER(ctypes.c_uint8)),
            ("P", ctypes.POINTER(ctypes.c_uint8)),
            ("S", ctypes.POINTER(ctypes.c_uint8)),
            ("M_size",ctypes.c_uint64),
            ("W_size", ctypes.c_uint64),
            ("P_size", ctypes.c_uint64),
            ("S_size", ctypes.c_uint64),
        ]

    """Define the parser for the MS bytes for a given chunk"""
    def ms_parser(buffer: np.ndarray) -> tuple:
        # First, we will convert the numpy bytes arr to Python bytes arr 
        # to use legacy code 
        bytes_buffer: bytearray = buffer.tobytes()

        # Retrieve the size of the individual data
        data_size_tuple: list = performance_json['sensor_size_settings'][performance_json['controller_names'].index('M')]

        # Assert that the bytes buffer is divisble by the length of readings
        assert(len(bytes_buffer) % data_size_tuple[0] == 0)

        # Next, we can call the legacy code for parsing a bytearray from the MS
        AS_channels, TS_channels, LS_channels, LS_temp = MS_util.parse_readings(bytes_buffer)

        return AS_channels, TS_channels, LS_channels, LS_temp
    
    """Define the parser for the World frames for a given chunk"""
    def world_parser(buffer: np.ndarray) -> np.ndarray:
        # Reintepret the bytes into a 16 bit unsigned array, as that is what 
        # is returned from the camera
        buffer = buffer.view(np.uint16)

        # First, we retrieve the shape of an individual frame 
        data_size_tuple: list = performance_json['sensor_size_settings'][performance_json['controller_names'].index('W')]

        # Now, let's calculate how many frames we have 
        num_frames: int = buffer.shape[0] // np.prod(data_size_tuple)

        # Reshape the buffer into its proper format
        buffer = buffer.reshape(num_frames, *data_size_tuple)

        # Take the mean of each frame if that is what is desired
        return buffer if use_mean_frame is False else np.max(buffer, axis=(1,2))


    """Define the parser for the pupil frames for a given chunk"""
    def pupil_parser(buffer: np.ndarray) -> np.ndarray:
        # The images are delivered to us as a stream of images in MJPEG compressed format. Therefore, 
        # we will have to use our own decoding routine to split all of the images' 
        # bytes into their own arrays, then pass them to cv2.imdecode
        data_size_tuple: list = performance_json['sensor_size_settings'][performance_json['controller_names'].index('P')]

        # First, we will convert the buffer to its raw bytes an initialize an array for the
        # frames 
        buffer_as_bytes: bytes = buffer.tobytes()
        frames: list = []

        # Find the starting and ending delims of the first image 
        start: int = buffer_as_bytes.find(b'\xFF\xD8')
        end: int = buffer_as_bytes.find(b'\xFF\xD9')

        # If we got an empty buffer, simply return an empty array now
        if(start == -1):
            return np.empty((0, *data_size_tuple), dtype=np.uint8)
        
        # Otherwise, we found a start and no ending delim, this is a problem and the image is malformed
        if(end == -1):
            raise Exception('ERROR: Could not find an ending delimeter in pupil buffer')
        
        # If we did find the start of an ending delim, we need to add 2 to it so when we 
        # copy we include that ending delim in the image 
        end += 2 

        # Append the first image to the frame array
        frames.append(buffer[start:end])

        # Now, we will conduct this operation on the rest of the images in the array
        while(start < buffer.shape[0] and end < buffer.shape[0]):
            # Find the new start and ends. We must looking for the next start after the last end
            # and the next end after this new start
            start: int = buffer_as_bytes.find(b'\xFF\xD8', end)
            end: int = buffer_as_bytes.find(b'\xFF\xD9', start)

            # If we don't have any more starting delims, we have converted all the iamges 
            # in this buffer. Simply return
            if(start == -1):
                break 
            
            # Otherwise, we found a starting delim without an ending delim. The image is malformed, so throw an error
            if(end == -1):
                raise Exception('ERROR: Could not find an ending delimeter in pupil buffer')

            # Otherwise, we found an ending delim. We must add 2 to it to include the ending delim in the bytes 
            # we attribute to the current frame 
            end+=2
            
            # Append the frame to the frame array
            frames.append(buffer[start:end])

        # Decode the images and convert the frames to a standardized np.array 
        buffer = np.array([cv2.imdecode(frame, cv2.IMREAD_GRAYSCALE) for frame in frames], dtype=np.uint8)

        # Return mean of each frame if desired 
        return buffer if use_mean_frame is False else np.mean(buffer, axis=(1,2))

    """Define the parser for the sunglasses buffer for a given chunk"""
    def sunglasses_parser(buffer: np.ndarray) -> np.ndarray:
        # The buffer passed in is made up of 8 bit unsigned ints, 
        # but the values reported by the sunglasses sensor require 12 bits, 
        # so lets convert to 16 and return

        return buffer.view(np.uint16)

        
    # Define argument and return type for the CPP deserialization function
    cpp_parser_lib.parse_chunk_binary.argtypes = [ctypes.c_char_p]
    cpp_parser_lib.parse_chunk_binary.restype = ctypes.POINTER(chunk_struct)

    # Define the argument type for free_chunk_struct
    cpp_parser_lib.free_chunk_struct.argtypes = [ctypes.POINTER(chunk_struct)]
    cpp_parser_lib.free_chunk_struct.restype = None

    # Define the set of parsers for each sensor
    parsers: dict = {'M': ms_parser, 'W': world_parser,
                     'P': pupil_parser, 'S': sunglasses_parser}

    """Helper function to parse chunks. Passes the path to CPP,
       executes, and reads in the deserialized data as np.arrays.
       Returns both the parsed chunk as a dictionary as well as its 
       CPP memory pointer to free. """
    def parse_chunk(path: str) -> tuple:
        # Initialize a container to hold return values 
        chunk_dict: dict = {}

        # Convert the Python string path to a chunk binary file
        # into a bytes object (C-compatible string)
        c_path: bytes = path.encode('utf-8')

        # Deserialize the chunk using CPP
        chunk_ptr: ctypes.POINTER(chunk_struct) = cpp_parser_lib.parse_chunk_binary(c_path)
        chunk: chunk_struct = chunk_ptr.contents

        # Let's splice out only the fields with sensor values and their buffer sizes 
        sensor_fields_and_sizes: list = {field.split('_')[0]: getattr(chunk, field)  
                                        for (field, _) 
                                        in chunk._fields_
                                        if '_size' in field} # Retrieve the sensor name by splicing out the _size portion of the name which is like M_size
        
        # Assert that the CPP executed without error
        assert(all(buffer_size != -1 for sensor, buffer_size in sensor_fields_and_sizes.items()))   # Error code: -1 means that the file does not exist
        assert(all(buffer_size != -2 for sensor, buffer_size in sensor_fields_and_sizes.items()))   # Error code -2 means that the file could not be opened

        # Now, we will iterate over the fields and read them in as numpy arrays
        for sensor_field, buffer_size in sensor_fields_and_sizes.items():
            # Next, we will read in a numpy array of that size
            buffer_as_np: np.ndarray = np.ctypeslib.as_array(getattr(chunk, sensor_field), shape=(buffer_size,))

            # Append this buffer name and its parsed value to the Python dict 
            chunk_dict[sensor_field] = parsers[sensor_field](buffer_as_np)

        # Return the data as Python-compatible objects    
        return chunk_ptr, chunk_dict

    # Deserialize the binary file via CPP and read in the
    # chunk's data into numpy arrays. 
    cpp_chunk_pointer, chunk_dict = parse_chunk(chunk_path)

    # Free the memory allocated in CPP for the chunk (note: for some reason this causes a segfault sometimes. I've commented it out
    # for now, but may need to see if this memory is actually freed or leaks in some way without this)
    #cpp_parser_lib.free_chunk_struct(cpp_chunk_pointer)

    return chunk_dict

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
        num_captured_frames = val_tuple[1]
        
        #If we want to only use the mean of each frame, not the entire frame
        if(use_mean_frame):
            frame_buffer = np.mean(frame_buffer, axis=(1,2))

        # Second value is always the settings buffer for this chunk
        # The settings are in the format [duration, FPS gain, exposure]
        #settings_buffer: np.ndarray = val_tuple[1].astype(np.float64)

        # Now splice only the captured frames from the settings buffer 
        #settings_buffer = settings_buffer[:num_captured_frames]
 
        print(f'Frame Buffer Shape: {frame_buffer.shape}')
        print(f'Captured Frames: {num_captured_frames}')
                                     
                                                                                     # Make this a float for MATLAB use later
        return {'frame_buffer': frame_buffer, 'settings_buffer': 0, 'num_frames_captured': float(num_captured_frames)}

    """Parser for the raw Pupil data per chunk"""
    def pupil_parser(val_tuple: tuple) -> dict:
        print(f'Length of Pupil vals: {len(val_tuple)}')

        # First value is always the frame buffer for this chunk
        frame_buffer: np.ndarray = val_tuple[0].astype(np.uint8)

        # Second value, third value are always num_captured_frames, observed FPS
        num_captured_frames: int = val_tuple[1]
        
        # If we want to only use the mean of each frame, not the entire frame
        if(use_mean_frame):
            frame_buffer = np.mean(frame_buffer, axis=(1,2))

        print(f'Frame Buffer Shape: {frame_buffer.shape}')
        print(f'Captured Frames: {num_captured_frames}')
         
                                                # Make this a float for MATLAB use later
        return {'frame_buffer': frame_buffer, 'num_frames_captured': float(num_captured_frames) }

    """Parser for the raw MS data per chunk"""
    def ms_parser(val_tuple: tuple) -> dict:    
        print(f'Length of MS Vals: {len(val_tuple)}')
        
        # First value is always the unparsed byte buffer 
        bytes_buffer: bytearray = val_tuple[0]

        # Second and third values are always the num_captured_frames and observed FPS
        num_captured_frames, observed_fps = val_tuple[1:]

        print(f'Reading Buffer Shape Before: {len(bytes_buffer)} | Num readings: {len(bytes_buffer)/MS_util.DATA_LENGTH}')

        # Splice out only the frames we captured 
        bytes_buffer: bytearray = bytes_buffer[:num_captured_frames * MS_util.DATA_LENGTH]

        print(f'Reading Buffer Shape After: {len(bytes_buffer)} | Num readings: {len(bytes_buffer)/MS_util.DATA_LENGTH}')

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