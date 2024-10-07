import os
import numpy as np
import argparse
import queue
import threading
import signal
import sys

"""Import utility functions from the MS utility file"""
ms_lib_path = os.path.join(os.path.dirname(__file__), '..', 'miniSpect')
sys.path.append(os.path.abspath(ms_lib_path))
from MS_util import read_SERIAL, write_SERIAL

"""Parse the command line arguments"""
def parse_args() -> str:
    parser = argparse.ArgumentParser(description='Communicate serially with the MS and save its readings to a desired location.')

    parser.add_argument('output_path', type=str, help='The folder in which to output the MS readings.')

    args = parser.parse_args()

    return args.output_path

"""If we receive a SIGTERM, terminate gracefully via keyboard interrupt"""
def handle_sigterm(signum, frame):
    print("Received SIGTERM. Raising KeyboardInterrupt...")
    raise KeyboardInterrupt
signal.signal(signal.SIGTERM, handle_sigterm)


def main():
    # Initialize output directory and names 
    # of reading files
    output_directory: str = parse_args()
    reading_names: list = ['AS_channels','TS_channels',
                           'LS_channels','LS_temp']

    # If the output directory does not exist, make it
    if(not os.path.exists(output_directory)): os.makedirs(output_directory)

    # Initialize write_queue for data to write
    write_queue: queue.Queue = queue.Queue()

    # Create a threading flag to declare when to stop indefinite recordings
    stop_flag: threading.Event = threading.Event()

    # Build thread processes for both capturing frames and writing frames 

    capture_thread: threading.Thread = threading.Thread(target=read_SERIAL, args=(write_queue, stop_flag))
    write_thread: threading.Thread = threading.Thread(target=write_SERIAL, args=(write_queue, reading_names, output_directory))
    
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