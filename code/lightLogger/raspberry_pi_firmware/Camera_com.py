# Import public libraries
import sys
import threading
import queue
import argparse
import os
import shutil
import numpy as np
import signal
import setproctitle

"""Import utility functions from the RPI recorder"""
recorder_lib_path = os.path.join(os.path.dirname(__file__), '..', 'camera')
sys.path.append(os.path.abspath(recorder_lib_path))
from world_recorder import preview_capture, record_live, record_video, record_video_signalcom, write_frame, vid_array_from_npy_folder, reconstruct_video, unpack_capture_chunks

"""Parse arguments via the command line"""
def parse_args() -> tuple:
    parser = argparse.ArgumentParser(description='Record videos from the camera via the RP')
    
    parser.add_argument('output_path', type=str, help='Path to output the recorded video to (including .avi file extension)') 
    parser.add_argument('duration', type=float, help='Duration of the video')
    parser.add_argument('--save_video', default=0, type=int, help='Choose whether to actually save the video or not')
    parser.add_argument('--save_frames', default=0, type=int, help='Choose whether or not to save frames of a video after finished recording')
    parser.add_argument('--preview', default=0, type=int, help='Display a preview before capture.')
    parser.add_argument('--initial_gain', default=1.0, type=float, help='Gain value with which to initialize the camera')
    parser.add_argument('--initial_exposure', default=1000, type=int, help='Exposure value with which to initialize the camera')
    parser.add_argument('--unpack_frames', default=0, type=int, help='Unpack the buffers of frames files into single frame files or not')
    parser.add_argument('--is_subprocess', default=0, type=int, help='A flag to tell this process if it has been run as a subprocess or not')
    parser.add_argument('--parent_pid', default=0, type=int, help='A flag to tell this process what the pid is of the parent process which called it')
    parser.add_argument('--signal_communication', default=0, type=int, help='A flag to tell this process to use signal communication with a master process when it is run as a subprocess')
    parser.add_argument('--starting_chunk_number', default=0, type=int, help='A flag to use when the main controller script crashes and it needs to resume where it left off')

    args = parser.parse_args()
    
    return args.output_path, args.duration, args.initial_gain, args.initial_exposure, bool(args.save_video), bool(args.save_frames), bool(args.preview), bool(args.unpack_frames), bool(args.is_subprocess), args.parent_pid, bool(args.signal_communication), args.starting_chunk_number

"""If we receive a SIGTERM, terminate gracefully via keyboard interrupt"""
def handle_sigterm(signum, frame):
    #print("Received SIGTERM. Raising KeyboardInterrupt...")
    raise KeyboardInterrupt
signal.signal(signal.SIGTERM, handle_sigterm)

# Create a threading flag to declare when to start recording 
# when run as a subprocess
go_flag: threading.Event = threading.Event()

# Create a threading flag to declare when to stop capturing 
# when run as a subprocess
stop_flag: threading.Event = threading.Event()

def main():
    # Set the program title so we can see what it is in TOP 
    setproctitle.setproctitle(os.path.basename(__file__))

    output_path, duration, initial_gain, initial_exposure, save_video, save_frames, preview, unpack_frames, is_subprocess, parent_pid, use_signalcom, starting_chunk_number = parse_args()
    
    # If the preview flag is true, first display a preview of the camera 
    # until it is in position
    if(preview is True):
        preview_capture()

    # Select whether to use the set-duration video recorder or the live recorder
    recorder: object = record_video_signalcom if use_signalcom is True else record_live if duration == float('INF') else record_video

    # Retrieve the experiment filename and the video extension
    filename, extension = os.path.splitext(output_path) 

    # Initialize a queue for frames to write 
    write_queue: queue.Queue = queue.Queue()

    # Build thread processes for both capturing frames and writing frames 
    capture_thread: threading.Thread = threading.Thread(target=recorder, args=(duration, write_queue, filename, 
                                                                               initial_gain, initial_exposure,
                                                                               stop_flag,
                                                                               is_subprocess,
                                                                               parent_pid,
                                                                               go_flag,
                                                                               starting_chunk_number))
    write_thread: threading.Thread = threading.Thread(target=write_frame, args=(write_queue, filename, 
                                                                                not use_signalcom))
    
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
    
    # Join threads regardless of keyboard interrupt or not
    finally:
        # Join the capture thread. Will finish the live capture, or wait until 
        # the capture_thread is entirely finished for recording videos
        # then wait for the write thread to complete
        for thread in (capture_thread, write_thread):
            thread.join()
    
    print('Capture/Write processes finished')

    # Unpack the frame buffers into individual frame files 
    if(unpack_frames is True):
        print('Unpacking camera frame chunks...')
        unpack_capture_chunks(filename)

    # Construct and save a video by the given filename and extension 
    # if desired
    if(save_video is True):
        print('Generating video...')
        frames: np.array = vid_array_from_npy_folder(filename)
        reconstruct_video(frames, output_path)
    
    # Remove the directory of frames if desired
    if(save_frames is not True): shutil.rmtree(filename)
    

if(__name__ == '__main__'):
    main()
