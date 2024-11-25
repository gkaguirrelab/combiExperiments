import os
import numpy as np
import argparse
import queue
import threading
import signal
import sys
import setproctitle

"""Import the MS recorder functions from the MS recorder file"""
ms_lib_path = os.path.join(os.path.dirname(__file__), '..', 'miniSpect')
sys.path.append(os.path.abspath(ms_lib_path))
from recorder import record_video, record_live, record_video_signalcom, write_SERIAL

"""Parse the command line arguments"""
def parse_args() -> str:
    parser = argparse.ArgumentParser(description='Communicate serially with the MS and save its readings to a desired location.')

    parser.add_argument('output_path', type=str, help='The folder in which to output the MS readings.')
    parser.add_argument('duration', type=float, help='Duration of the video')
    parser.add_argument('--is_subprocess', default=0, type=int, help='A flag to tell this process if it has been run as a subprocess or not')
    parser.add_argument('--parent_pid', default=0, type=int, help='A flag to tell this process what the pid is of the parent process which called it')
    parser.add_argument('--signal_communication', default=0, type=int, help='A flag to tell this process to use signal communication with a master process when it is run as a subprocess')
    parser.add_argument('--starting_chunk_number', default=0, type=int, help='A flag to use when the main controller script crashes and it needs to resume where it left off')

    args = parser.parse_args()

    return args.output_path, args.duration, bool(args.is_subprocess), args.parent_pid, bool(args.signal_communication), args.starting_chunk_number

"""If we receive a SIGTERM, terminate gracefully via keyboard interrupt"""
def handle_sigterm(signum, frame):
    print("Received SIGTERM. Raising KeyboardInterrupt...")
    raise KeyboardInterrupt
signal.signal(signal.SIGTERM, handle_sigterm)

# Create a threading flag to declare when to start recording 
# when run as a subprocess
go_flag: threading.Event = threading.Event()

"""Add a handle to receive a USRSIG1 from the main process 
   to begin capturing when all sensors have reported ready"""
def handle_gosignal(signum, frame=None):
    #print(f'World Cam: Received GO signal')
    go_flag.set()

signal.signal(signal.SIGUSR1, handle_gosignal)

# Create a threading flag to declare when to stop capturing 
# when run as a subprocess
stop_flag: threading.Event = threading.Event()

def main():
    # Set the program title so we can see what it is in TOP 
    setproctitle.setproctitle(os.path.basename(__file__))

    # Initialize output directory and names 
    # of reading files
    output_directory, duration, is_subprocess, parent_pid, use_signalcom, starting_chunk_number = parse_args()
    reading_names: list = ['AS_channels','TS_channels',
                           'LS_channels','LS_temp']

    # Select whether to use the set-duration video recorder or the live recorder
    recorder: object = record_video_signalcom if use_signalcom is True else record_live if duration == float('INF') else record_video

    # Initialize write_queue for data to write
    write_queue: queue.Queue = queue.Queue()

    # Build thread processes for both capturing frames and writing frames 
    capture_thread: threading.Thread = threading.Thread(target=recorder, args=(duration, write_queue,
                                                                               output_directory, 
                                                                               reading_names, stop_flag,
                                                                               is_subprocess, parent_pid, go_flag,
                                                                               starting_chunk_number))
    write_thread: threading.Thread = threading.Thread(target=write_SERIAL, args=(write_queue, reading_names, 
                                                                                output_directory, not use_signalcom))
    
    # Begin the threads
    for thread in (capture_thread, write_thread):
        thread.start()

    # Try capturing
    try:
        capture_thread.join()

    # If the capture was canceled via Ctrl + C
    except KeyboardInterrupt:
        # Set the stop flag to tell a live capture to stop
        stop_flag.set()

    # Join threads regardless of interrupt or not. Ensure they are joined
    finally:
        # Wait until the capture_thread is entirely finished for recording videos
        # Then wait for the write thread to complete
        for thread in (capture_thread, write_thread):
            thread.join()
  

if(__name__ == '__main__'):
    main()