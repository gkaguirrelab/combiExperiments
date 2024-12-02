"""Import public libraries"""
import numpy as np 
import multiprocessing as mp 
import pathlib
import os
import sys
from picamera2 import Picamera2
import serial
import time

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

"""Define a queue that will hold one second bursts of data"""
data_queue: mp.Queue = mp.Queue()

"""Define an array of data capable of storing 'one second' from all sensors"""
data_buffer: np.ndarray = np.empty((200, 480, 640+150)) # +150 for MS message

"""Initialize all of the sensors of the device"""
def initialize_sensors() -> tuple:
    # Initialize the world camera
    print('\tInitializing World Cam: ', end="")
    world_cam: Picamera2 = world_recorder.initialize_camera()
    print('World Cam Initialized!')
    
    # Initialize the MS
    print('\tInitializing MS: ', end="")
    MS: serial.Serial = MS_recorder.initialize_ms()
    print('MS Initialized!')

    return world_cam, MS

"""Close all of the sensors of the device"""
def close_sensors(sensors: tuple):
    # Iterate over the sensors
    for sensor in sensors:
        # Close a given sensor
        sensor.close()

def main():
    # Initialize the sensors
    print('Initializing sensors...')
    world_cam, MS = initialize_sensors()

    print('Simulating exection...')
    time.sleep(2)

    print('Closing sensors')
    close_sensors((world_cam, MS))







if(__name__ == '__main__'):
    main() 
