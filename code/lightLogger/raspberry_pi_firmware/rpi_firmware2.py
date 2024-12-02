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



def write_process(names: tuple, data_queues: tuple):
    # Create a dictionary of things to write per sensor
    write_dict: dict = {name: collections.deque()
                       for name in names}

    # Initialize a counter to determine when all subprocesses are finished
    finished_counter: int = 0

    # While true, monitor the ready queue
    waiting_for_values: bool = True

    chunk_num: int = 0 
    while(waiting_for_values is True):
        for name, mpqueue in zip(names, data_queues):
            # Try to retrieve something from this queue
            # very quickly (so it doesn't build up)
            try:
                ret = mpqueue.get(timeout=0.1)
            
            # If the queue is empty, don't wait for it to arrive, just 
            # keep going blazing fast
            except queue.Empty:
                continue
            
            # If we received a signal that this queue is done, 
            # increment the done counter
            if(ret is None):
                finished_counter += 1 
            else:
                print(f'Sender: {name} | Value shape: {ret.shape} | Queue size: {mpqueue.qsize()}')

                # Append this value to the write dict for this sensor
                write_dict[name].append(ret)
                
                # If all sensors have at least one item to write, write it out 
                if(all(len(write_queue) > 0 for sensor, write_queue in write_dict.items())):
                    # Gather the tuple to write as the tuple 
                    tuple_to_write: tuple = tuple(write_queue.popleft() for sensor, write_queue in write_dict.items())

                    with open(f"/media/rpiControl/FF5E-7541/completelyNew/{chunk_num}.pkl", 'wb') as f:
                        pickle.dump(tuple_to_write, f)

                    chunk_num += 1

            # If all subprocesses are done capturing, finish outputting
            if(finished_counter == len(names)):
                waiting_for_values = False
                break

def main():
    # Initailize a list to hold process objects and wait for their execution to finish
    processes: list = []

    # Initialize tuples of names, devices, and their respective recording function
    names: tuple = ('Output', 'World Cam', 'MS')
    recorders: tuple = (write_process, world_recorder.lean_capture, MS_recorder.lean_capture)
    data_queues: tuple = tuple(mp.Queue() for _ in range(len(names[1:])))
    process_args: tuple = tuple([ (names[1:], data_queues) ] + [ (data_queues[i], 10) for i in range(len(names[1:])) ])
    CPU_and_priorities: tuple = tuple((i, -20) for i in range(len(names[1:])))


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
