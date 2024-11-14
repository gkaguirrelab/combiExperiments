import numpy as np
import queue
import threading
import time
import serial
import os
import sys
import signal
from MS_util import reading_to_string, parse_SERIAL

"""Write MS readings taken from the serial connection"""
def write_SERIAL(write_queue: queue.Queue, reading_names: list, output_directory: str):
    # Open the reading file handles
    reading_file_handles: list = [open(os.path.join(output_directory, reading_name + '.csv'), 'a')
                                  for reading_name in reading_names]

    # Write while we are receiving information
    while(True):
        print(f'MS Queue size {write_queue.qsize()}')

        # Retrieve an item from the write queue
        ret: tuple = write_queue.get()

        # Break from writing if we have finished a recording
        if(ret is None):
            break
        
        # Otherwise, extract the information from the item
        read_time, bluetooth_bytes = ret

        # Parse the the readings into np.arrays 
        readings: tuple = parse_SERIAL(bluetooth_bytes)

        # Iterate over the reading files and append this info to them
        for reading_file, reading in zip(reading_file_handles, readings):
            reading_file.write(reading_to_string(read_time, reading))
    
    # Close all of the file handles 
    for file_handle in reading_file_handles:
        file_handle.close()

"""Record from all of the MS sensors for an unspecified amount of time"""
def record_live(duration: float, write_queue: queue.Queue,
                stop_flag: threading.Event) -> None: 

    raise NotYetImplementedError

    return

"""Record from all of the MS sensors for a set length of time"""
def record_video(duration: float, write_queue: queue.Queue,
                 stop_flag: threading.Event,
                 is_subprocess: bool, 
                 parent_pid: int, 
                 go_flag: threading.Event) -> None:

        # Initialize a serial connection to the Minispect 
        # and how many bytes it will be transfering
        ms, msg_length = initialize_ms()

        # Sleep for a certain amount of time (equal to all other sensors)
        # while the sensors initialize 
        time.sleep(2)

        # If we were run as a subprocess, send a message to the parent 
        # process that we are ready to go
        if(is_subprocess): 
            print('MS: Initialized. Sending ready signal...')
            os.kill(parent_pid, signal.SIGUSR1)

            # While we have not receieved the GO signal wait 
            while(not go_flag.is_set()):
                print('MS: Waiting for GO signal...')
                time.sleep(3)

        # Once the go signal has been received, begin capturing
        print('MS: Beginning capture')

        # Initialize the start time of recording
        start_time: float = time.time() 

        # Record the measurements for the given duration
        while(True):    
            # Determine the current time 
            current_time: float = time.time()

            # If we have recorded for the duration, break   
            if((current_time - start_time) >= duration):
                break
            
            # Read a token from the MS 
            token: bytes = ms.read(1)

            #Check if the token is equal to the starting delimeter
            if(token == b'<'):     
                #print(f'Received MS TRANSMISSION @{time.time()}')      
                
                # Read the buffer over the serial port (- 2 for the begin/end delimeters)
                reading_buffer: bytes = ms.read(msg_length - 2)

                # Assert we didn't overread the buffer by reading the next byte and ensuring
                # it's the ending delimeter 
                assert(ms.read(1) == b'>')

                #print(f"Size of reading buffer: {len(reading_buffer)}")
                AS, TS, LI, temp = parse_SERIAL(reading_buffer)

                #print(f'AS CHANNELS: {AS}')
                #print(f'TS CHANNELS: {TS}')
                #print(f'LI CHANNELS: {LI}')
                #print(f'TEMP: {temp}')

                # Append it to the write queue
                write_queue.put(['NA',  reading_buffer])

                # Flush the reading buffer 
                reading_buffer = None
        
        # Signal the end of the write queue
        write_queue.put(None)
        
        # Close the serial connection
        ms.close()

        return 

"""Initialize a connection with the minispect over the serial port
   and return the MS serial object"""
def initialize_ms() -> serial.Serial:
    # Hard Code the port the MS connects to for Linux and MAC
    # its baudrate, and the length of a message in bytes
    com_port: str = '/dev/ttyACM0' if sys.platform.startswith('linux') else '/dev/tty.usbmodem141301'
    baudrate: int = 115200
    msg_length: int = 150

    # Connect to the MS device
    print('Connecting to ms...')
    ms: serial.Serial = serial.Serial(com_port, baudrate, timeout=1)

    return ms, msg_length


def main():
    pass 

if(__name__ == '__main__'):
    main()