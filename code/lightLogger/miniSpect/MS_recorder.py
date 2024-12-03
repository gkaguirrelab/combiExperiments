import numpy as np
import queue
import threading
import time
import serial
import os
import psutil
import sys
import signal
from MS_util import reading_to_string, parse_SERIAL
import traceback
import multiprocessing as mp
import setproctitle

"""Define the length of a given communication from the MS in bytes"""
MSG_LENGTH: int = 150

"""Write MS readings taken from the serial connection"""
def write_SERIAL(write_queue: queue.Queue, reading_names: list, output_directory: str, generate_readingfiles: bool=True):
    # Open the reading file handles (if we are not using signals to communicate)
    reading_file_handles: list = [open(os.path.join(output_directory, reading_name + '.csv'), 'a')
                                  for reading_name in reading_names] if generate_readingfiles else []

    # Write while we are receiving information
    while(True):
        print(f'MS Queue size {write_queue.qsize()}')

        # Retrieve an item from the write queue
        ret: tuple = write_queue.get()
        # Break from writing if we have finished a recording
        if(ret is None):
            break

        # Otherwise, extract the information from the item
        read_time, bluetooth_bytes = ret[:2]

        # If the length is greater than 2, we have passed the file handles to the write 
        # queue (for signal communication)
        if(len(ret) > 2):
            # Extract the (potentially) new reading filehandles
            new_reading_filehandles = ret[-1]

            # See if we need to swap the current reading filehandles
            if(len(reading_file_handles) == 0 or reading_file_handles[0].name != new_reading_filehandles[0].name):
                # If we need to swap, first close all of the old filehandles 
                for handle in reading_file_handles:
                    handle.close()
                
                # Now swap 
                reading_file_handles = new_reading_filehandles

        # Parse the the readings into np.arrays 
        readings: tuple = parse_SERIAL(bluetooth_bytes)

        # Iterate over the reading files and append this info to them
        for reading_file, reading in zip(reading_file_handles, readings):
            reading_file.write(reading_to_string(read_time, reading))
    
    # Close all of the file handles (if not closed already)
    for file_handle in reading_file_handles:
        if(not file_handle.closed): file_handle.close()

"""Record from all of the MS sensors for an unspecified amount of time"""
def record_live(duration: float, write_queue: queue.Queue,
                stop_flag: threading.Event) -> None: 

    raise NotYetImplementedError

    return


"""A helper function that contains the meat of capturing 
   a video of a set length, for use when communicating 
   via signals"""
def capture_helper(ms: serial.Serial, duration: float, 
                  write_queue: queue.Queue,
                  msg_length: int,
                  reading_filehandles: list) -> None:
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
            # Read the buffer over the serial port (- 2 for the begin/end delimeters)
            reading_buffer: bytes = ms.read(MSG_LENGTH - 2)

            # Assert we didn't overread the buffer by reading the next byte and ensuring
            # it's the ending delimeter 
            assert(ms.read(1) == b'>')
            AS, TS, LI, temp = parse_SERIAL(reading_buffer)

            # Append it to the write queue
            write_queue.put(['NA',  reading_buffer, reading_filehandles])

            # Flush the reading buffer 
            reading_buffer = None


"""Record from all of the MS sensors for a set length of time
   communicating with a parent process via signals"""
def record_video_signalcom(duration: float, write_queue: queue.Queue,
                           filename: str, reading_names: list,
                           stop_flag: threading.Event,
                           is_subprocess: bool, 
                           parent_pid: int, 
                           go_flag: threading.Event,
                           burst_num: int = 0) -> None:

    # Retrieve the name of the controller this recorder is operating out of
    controller_name: str = setproctitle.getproctitle()
    
    # Define the path to the controller READY files
    READY_file_dir: str = "/home/rpiControl/combiExperiments/code/lightLogger/raspberry_pi_firmware/READY_files"
    GO_file_dir: str = "/home/rpiControl/combiExperiments/code/lightLogger/raspberry_pi_firmware/GO_files"
    STOP_file_dir: str = "/home/rpiControl/combiExperiments/code/lightLogger/raspberry_pi_firmware/STOP_files"

    # Define the name of this controller's READY file 
    READY_file_name: str = os.path.join(READY_file_dir, f"{controller_name}|READY")

    # Initialize a serial connection to the Minispect 
    # and how many bytes it will be transfering
    try:
        print('Initializing MS')
        ms: serial.Serial = initialize_ms()
    except Exception as e:
        # Print the traceback to stderr for this exception 
        traceback.print_exc()
        print(e)
        print('Failed to initailize MiniSpect. Exiting...')
        sys.exit(1)


    # If we were run as a subprocess, send a message to the parent 
    # process that we are ready to go
    try:
        if(is_subprocess): 
            print('MS: Initialized. Sending ready signal...')
            
            # Add a READY file for this controller
            with open(READY_file_name, 'w') as f: pass

            #os.kill(parent_pid, signal.SIGUSR1)

            # While we have not receieved the GO signal wait 
            start_wait: float = time.time()
            last_read: float = time.time()
            while(not go_flag.is_set()):
                # Set the GO flag if we have received a GO signal
                if(len(os.listdir(GO_file_dir)) > 0): go_flag.set()
                
                # Capture the current time
                current_wait: float = time.time()

                # If the parent process is no longer existent, something has gone wrong
                # and we should quit 
                if(not psutil.pid_exists(parent_pid)):
                    raise Exception('ERROR: Parent process was killed')

                # Every 2 seconds, output a message
                if((current_wait - last_read) >= 2):
                    print('MS: Waiting for GO signal...')
                    last_read = current_wait
    
    # Catch if there was an error in some part of the pipeline and we did not receive 
    # a go signal in the appropriate amount of time
    except Exception as e:
        # Close the serial connection to the MS
        ms.close()
        
        # Print the tracback to stderr for what caused this exception
        traceback.print_exc()
        print(e)
        sys.exit(1)


    # Now, the MS was initialized and the first ready was sent and the first go was received
    # Therefore, let's record the amount of time we desire
    
    # Define the starting burst number
    # and the thus the initial filename
    # settings file
    filename : str = filename.replace('burstX', f"burst{burst_num}") 
    if(not os.path.exists(filename)): os.mkdir(filename)
    reading_filehandles: list = [open(os.path.join(filename, reading_name + '.csv'), 'a')
                                  for reading_name in reading_names]

    # Once the GO signal has been received, begin capturing chunks until we 
    # receive a stop signal
    while(True):     
        # Use the milliseconds of time gaps between GO signals to generate files and hopefully not add 
        # any delay in the start of a burst capture
        # Akin to racing the beam on ATARI 2600, pretty cool!

        # STOP if we have received a STOP signal
        if(len(os.listdir(STOP_file_dir)) > 0): break 

        # Set the GO flag if we have received a GO signal
        if(len(os.listdir(GO_file_dir)) > 0): go_flag.set() 

        if(not os.path.exists(filename)): os.mkdir(filename) 

        if(reading_filehandles[0].name != os.path.join(filename, reading_names[0])): 
            reading_filehandles = [open(os.path.join(filename, reading_name + '.csv'), 'a')
                                  for reading_name in reading_names]

        # While we have the GO signal, record a burst
        while(go_flag.is_set()):
            # Capture duration worth of frames
            capture_helper(ms, duration, write_queue, 
                          MSG_LENGTH, reading_filehandles)

            # Stop recording until we receive the GO signal again 
            go_flag.clear()
            # Try except here because multiple controllers could be trying to remove this file at once 
            # so it could be deleted by the time another goes to delete it
            try:
                for file in os.listdir(GO_file_dir): os.remove(os.path.join(GO_file_dir, file))
            except:
                pass

            # Report to the parent process we are ready to go for the next burst 
            assert(not os.path.exists(READY_file_name))
            with open(READY_file_name, 'w') as f: pass
            print(f'MS: Finished burst: {burst_num+1} | Generating READY signal for parent: {parent_pid}!')
        
            # Increment the burst number += 1 
            burst_num += 1

            # Update the filename for the new burst number
            filename = filename.replace(f'burst{burst_num-1}', f"burst{burst_num}")

        
    # Signal the end of the write queue
    write_queue.put(None)
    
    # Close the serial connection
    ms.close()

    # Iterate over the filehandles and remove unncessary files (files we created but didn't populate)
    for handle in reading_filehandles:
        # Make sure it is closed
        if(not handle.closed): handle.close()

        # Remove it as well if it is empty
        if(os.path.getsize(handle.name) == 0): os.remove(handle.name)
    
    # Now check to see if the directory for the files is empty 
    if(os.path.exists(filename) and len(os.listdir(filename)) == 0): os.rmdir(filename)

    # Remove any left over READY file if it is empty 
    if(os.path.exists(READY_file_name)): os.remove(READY_file_name)

    return 

"""Record from all of the MS sensors for a set length of time"""
def record_video(duration: float, write_queue: queue.Queue,
                 filename: str, reading_names: list,
                 stop_flag: threading.Event,
                 is_subprocess: bool, 
                 parent_pid: int, 
                 go_flag: threading.Event,
                 burst_num: int=0) -> None:

        # Initialize a serial connection to the Minispect 
        # and how many bytes it will be transfering
        try:
            print('Initializing MS')
            ms: serial.Serial = initialize_ms()
        except Exception as e:
            # Print the traceback to stderr for this exception 
            traceback.print_exc()
            print(e)
            print('Failed to initailize MiniSpect. Exiting...')
            sys.exit(1)


        # If we were run as a subprocess, send a message to the parent 
        # process that we are ready to go
        try:
            if(is_subprocess): 
                print('MS: Initialized. Sending ready signal...')
                os.kill(parent_pid, signal.SIGUSR1)

                # While we have not receieved the GO signal wait 
                start_wait: float = time.time()
                last_read: float = time.time()
                while(not go_flag.is_set()):
                    # Capture the current time
                    current_wait: float = time.time()

                    # If the parent process is no longer existent, something has gone wrong
                    # and we should quit 
                    if(not psutil.pid_exists(parent_pid)):
                        raise Exception('ERROR: Parent process was killed')

                    # Every 2 seconds, output a message
                    if((current_wait - last_read) >= 2):
                        print('MS: Waiting for GO signal...')
                        last_read = current_wait
        
        # Catch if there was an error in some part of the pipeline and we did not receive 
        # a go signal in the appropriate amount of time
        except Exception as e:
            # Print the tracback to stderr for what caused this exception
            traceback.print_exc()
            print(e)
            sys.exit(1)
            

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
                reading_buffer: bytes = ms.read(MSG_LENGTH - 2)

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

def lean_capture_helper(ms: serial.Serial, duration: int, reading_buffer: np.ndarray, 
                        write_queue: mp.Queue):

    # Capture the start time of recording 
    start_time: float = time.time()

    # Capture duration worth of frames 
    second_num: int = 0
    frame_num: int = 0 
    while(True):
        # Retrieve the current time
        current_time: float = time.time()

        # Calculate the elapsed time from the start 
        elapsed_time: float = current_time - start_time

        # Calculate the elapsed_time as int (used for placing into the buffer)
        second_num: float = int(elapsed_time)

        # If reached desired duration, stop recording
        if(elapsed_time >= duration):
            break  

        # Read a token from the MS 
        token: bytes = ms.read(1)

        #Check if the token is equal to the starting delimeter
        if(token == b'<'):    
            # Read the buffer over the serial port (- 2 for the begin/end delimeters)
            reading_bytes: bytes = ms.read(MSG_LENGTH - 2)

            # Assert we didn't overread the buffer by reading the next byte and ensuring
            # it's the ending delimeter 
            assert(ms.read(1) == b'>')

            # Append it to the write queue
            reading_buffer[second_num] == np.frombuffer(reading_bytes, dtype=np.uint8)

            # Flush the reading buffer 
            reading_bytes = None
            
            # Append the frame number
            frame_num += 1 

    # Record timing of end of capture 
    end_time: float = time.time()

    # Calculate the approximate FPS the frames were taken at 
    # (approximate due to time taken for other computation)
    observed_fps: float = (frame_num)/(end_time-start_time)
    print(f'MS captured {frame_num} at ~{observed_fps} fps')
    
    # Send this info to the write queue 
    write_queue.put(('M', reading_buffer, frame_num, observed_fps))

    # Signal the end of the write queue
    write_queue.put(('M', None)) 

def lean_capture(write_queue: mp.Queue, receive_queue: mp.Queue, duration: int):
    # Connect to and initialize the MS
    ms = initialize_ms()

    # Define a buffer for 5 readings at a time
    reading_buffer: np.ndarray = np.empty((duration, MSG_LENGTH), dtype=np.uint8)

    print('MS | Initialized')
    STOP: bool = False
    while(STOP is False):
        print('MS | Awaiting GO')
        # Retrieve whether we should go or not from 
        # the main process 
        GO: bool | int = receive_queue.get()

        # If GO received special flag, we end completely
        if(GO is False):
            print('MS | Received STOP.')
            STOP = True
            break    

        # Otherwise, we capture a burst of duration long 
        while(GO is True):
            print('MS | Capturing chunk')

            # Capture a burst of frames
            lean_capture_helper(ms, duration, reading_buffer, write_queue)

            # Set GO back to False 
            GO = False
    
    # Append to the main process queue and let it know we are really done 
    write_queue.put(('M', False))

    # Close the camera
    print(f'MS | Closing')
    ms.close()

"""Initialize a connection with the minispect over the serial port
   and return the MS serial object"""
def initialize_ms() -> serial.Serial:
    # Hard Code the port the MS connects to for Linux and MAC
    # its baudrate, and the length of a message in bytes
    com_port: str = '/dev/ttyACM0' if sys.platform.startswith('linux') else '/dev/tty.usbmodem141301'
    baudrate: int = 115200

    # Connect to the MS device
    ms: serial.Serial = serial.Serial(com_port, baudrate, timeout=1)

    return ms


def main():
    pass 

if(__name__ == '__main__'):
    main()