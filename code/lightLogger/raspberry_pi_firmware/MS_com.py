import os
import numpy as np
from utility.MS_util import read_SERIAL, write_SERIAL
import argparse
import queue
import threading
import signal

"""If we receive a SIGTERM, terminate gracefully via keyboard interrupt"""
def handle_sigterm(signum, frame):
    print("Received SIGTERM. Raising KeyboardInterrupt...")
    raise KeyboardInterrupt
signal.signal(signal.SIGTERM, handle_sigterm)

def main():
    # Retrieve the name of the device to connect with
    #id: str = parse_args()

    # Initialize output directory and names 
    # of reading files
    output_directory: str = './readings/MS'
    reading_names: list = ['AS_channels','TS_channels',
                         'LI_channels','LI_temp']

    # If the output directory does not exist, make it
    if(not os.path.exists(output_directory)): os.mkdir(output_directory)

    # Initialize write_queue for data to write
    write_queue = queue.Queue()

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

        # the capture_thread is entirely finished for recording videos
        capture_thread.join()

        # Wait for the write thread to complete
        write_thread.join()

    # Join threads regardless of interrupt or not. Ensure they are joined
    finally:
        for thread in (capture_thread, write_thread):
            thread.join()
  

if(__name__ == '__main__'):
    main()