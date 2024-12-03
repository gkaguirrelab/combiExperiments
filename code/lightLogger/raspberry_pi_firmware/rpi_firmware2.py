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

# Append these paths to the current path
for path in (world_cam_recorder_path, MS_recorder_path):
    sys.path.append(path)

# Import the libraries 
import world_recorder 
import MS_recorder


""""""
def write_process(names: tuple, data_queue: mp.Queue):
    # Create a dictionary of things to write per sensor
    write_dict: dict = {name: collections.deque()
                       for name in names}

    # Initialize a counter to determine when all subprocesses are finished
    finished_counter: int = 0

    # While true, monitor the ready queue
    waiting_for_values: bool = True

    chunk_num: int = 0 
    while(waiting_for_values is True):
            ret = data_queue.get()
            
            # If we received a signal that this queue is done, 
            # increment the done counter
            if(ret is None):
                finished_counter += 1 
            else:
                # Extract the name of the sensor sending us this information 
                # as well as the values it is sending us
                name, *vals = ret

                print(f'Sender: {name} | Number of Vals: {len(vals)} | Queue size: {data_queue.qsize()}')

            # If all subprocesses are done capturing, finish outputting
            if(finished_counter == len(names)):
                print('RECEIVED ALL END SIGNALS')
                waiting_for_values = False
                break

def main():
    # Initailize a list to hold process objects and wait for their execution to finish
    processes: list = []

    # Initialize a multiprocessing-safe queue to store data 
    # from the sensors
    data_queue: mp.Queue = mp.Queue()

    # Define the number of recording bursts and duration (s) of a recording burst 
    burst_numbers: int = 5
    burst_duration: int = 10

    # Initialize tuples of names, recording functions, and their respective arguments
    names: tuple = ('Output', 'World Cam', 'MS')
    recorders: tuple = (write_process, world_recorder.lean_capture, MS_recorder.lean_capture)
    process_args: tuple = tuple([ (names[1:], data_queue) ] + [ (data_queue, burst_duration) for i in range(len(names[1:])) ])

    # Generate the process objects
    for p_num, (name, recorder, args) in enumerate(zip(names, recorders, process_args)):
        print(f'Beginning process: {name}')

        # Spawn the recorder process (not yet started)
        process: mp.Process = mp.Process(target=recorder, args=(*args,))    

        # Append this process object to the list 
        processes.append(process)

        # Start the process 
        process.start()

    # Wait for the processes to finish 
    for process in processes:
        process.join()

    return 


if(__name__ == '__main__'):
    main() 
