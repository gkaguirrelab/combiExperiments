"""Import public libraries"""
import numpy as np 
import multiprocessing as mp 
import pathlib
import os
import sys
from picamera2 import Picamera2
import serial
import time
import queue
import collections
import pickle

"""Import custom libraries"""
# First generate the path to the lightLogger dir and Pi utility file
light_logger_dir_path: str = str(pathlib.Path(__file__).parents[1]) 
pi_util_path: str = os.path.join(os.path.dirname(__file__), 'utility')

# Then generate the paths to all of the recorders
world_cam_recorder_path: str = os.path.join(light_logger_dir_path, 'camera') 
MS_recorder_path: str = os.path.join(light_logger_dir_path, 'miniSpect')
pupil_recorder_path: str = os.path.join(light_logger_dir_path, 'pupil')

# Append these paths to the current path
for path in (world_cam_recorder_path, MS_recorder_path, pupil_recorder_path):
    sys.path.append(path)

# Import the libraries 
import world_recorder 
import MS_recorder
import pupil_recorder

# Placeholder for testing purposes
test_filepath: str = "/media/rpiControl/FF5E-7541/fixBufferIssue_0.1hz_0NDF"

""""""
def write_process(names: tuple, receive_queue: mp.Queue, 
                 send_queue: mp.Queue, n_chunks: int):

    # Define a dictionary to hold the chunk information for each sensor
    write_dict: dict = {name[0]: None
                        for name in names}
    
    # Define two boolean dictionares to hold the states of the sensors
    # as READY to record next chunk and FINISHED recording all chunks
    ready_dict: dict = {name[0]: False 
                        for name in names}
    
    finished_dict: dict = {name[0]: False 
                        for name in names}

    # Initialize a counter to determine when each sensor is finished
    # recording its chunk
    recording_finished_counter: int = 0

    # Initialize a counter to determine when each subprocess is completely finished
    process_finished_counter: int = 0

    # While true, monitor the ready queue
    chunks_completed: int = 0
    chunk_filecounter: int = 0 
    waiting_for_values: bool = True
    while(waiting_for_values is True):
            # Retrieve an item from the received data queue
            ret = receive_queue.get()
            
            # Extract the name of the sensor sending us this information 
            # as well as the potential values it is sending us
            name, *vals = ret

            print(f'Main Process | Received a message from: {name} | Number of Vals: {len(vals)} | Queue size: {receive_queue.qsize()}')
            
            # If we have sent only one val, it is either None or False
            if(len(vals) == 1):
                # Assert that this is true
                program_code, = vals 
                assert(program_code is None or program_code is False)
                
                # Determine who we have received a CHUNK-DONE signal from 
                if(program_code is None):
                    # Note that this sensor is ready for the next round
                    ready_dict[name] = True
                    print(f'READY Dict: {ready_dict}')
                
                # Determine who we have received an END-OF-RECORDING signal from 
                elif(program_code is False):
                    # Note that this sensor is completely finished recording 
                    finished_dict[name] = True 
                    print(f'FINISHED Dict: {finished_dict}')    

                # Determine whether to send GO or STOP signals (if all sensors are ready)
                if(all(state is True for name, state in ready_dict.items())):
                    # Incrememnt the finished chunks container 
                    chunks_completed += 1 

                    print(f'Chunks completed: {chunks_completed}/{n_chunks}')

                    # Determine whether to send GO or STOP based on if we have captured 
                    # the desired number of chunks 
                    signal: bool = True if chunks_completed < n_chunks else False

                    # Clear the READY dict 
                    for name, state in ready_dict.items():
                        ready_dict[name] = not state

                    # Populate the queue with one of these GO signals for each sensor
                    for _ in range(len(names)): send_queue.put(signal)

                # Determine whether to STOP waiting for values (if all sensors have finished)
                if(all(state is True for name, state in finished_dict.items())):
                    # Stop waiting for values and break out of the while loop 
                    waiting_for_values = not waiting_for_values
                    break
                     
            # Otherwise, we have received some sensor data
            else:
                # Assert there is not any data left for this sensor in the dict
                # to make sure we are not overwriting any data
                assert(write_dict[name] is None)

                # Place this sensor's data into the dictionary, 
                write_dict[name] = tuple(vals)

                # If all sensors have something to write from a chunk, we are ready to write
                if(all(value is not None for sensor, value in write_dict.items())):
                    # Generate the path to this file
                    filepath: str = os.path.join(test_filepath, f"{chunk_filecounter}.pkl")

                    # Dump the object to the file
                    with open(filepath, 'wb') as f:
                        pickle.dump(write_dict, f, protocol=5)

                    # Clear the write dict
                    for name in write_dict.keys():
                        write_dict[name] = None

                    # Increment the chunk file this is 
                    chunk_filecounter += 1 

def main():
    # Initailize a list to hold process objects and wait for their execution to finish
    processes: list = []

    # Define the number of recording bursts and duration (s) of a recording burst 
    n_bursts: int = 6 * 15 # 45 minutes
    burst_duration: int = 10

    # Initialize tuples of names for the processes we will use
    names: tuple = ('Output', 'World', 'MS', 'Pupil')

    # Initialize a multiprocessing-safe queue to store data 
    # from the sensors
    receive_data_queue: mp.Queue = mp.Queue()
    
    # Initialze a multiprocessing-safe queue to send GO signals 
    # to the sensors 
    send_data_queue: mp.Queue = mp.Queue()

    # Define the recorders used by the processes as well as their respective arguments
    recorders: tuple = (write_process, world_recorder.lean_capture, MS_recorder.lean_capture, pupil_recorder.lean_capture)
    process_args: tuple = tuple([ (names[1:], receive_data_queue, send_data_queue, n_bursts) ] + [ (receive_data_queue, send_data_queue, burst_duration) for i in range(len(names[1:])) ])

    # Generate the process objects
    start_time: float = time.time()
    for p_num, (name, recorder, args) in enumerate(zip(names, recorders, process_args)):
        print(f'Beginning process: {name}')

        # Spawn the recorder process (not yet started)
        process: mp.Process = mp.Process(target=recorder, args=(*args,))    

        # Append this process object to the list 
        processes.append(process)

        # Start the process 
        process.start()

    # Sleep for 2 seconds to allow for initialization, then send GO signals 
    # for the first time
    time.sleep(2)
    for _ in range(len(names[1:])): send_data_queue.put(True)

    # Wait for the processes to finish 
    for process in processes:
        process.join()

    end_time: float = time.time()

    elapsed_time: float = end_time - start_time

    print(f'Took {elapsed_time} seconds to record {n_bursts} chunks of {burst_duration} seconds')

    return 


if(__name__ == '__main__'):
    main() 
