import os
import sys
import argparse
import threading
import queue
import shutil
import numpy as np
import signal

"""Import utility functions from the pupil recorder"""
recorder_lib_path = os.path.join(os.path.dirname(__file__), '..', 'pupil')
sys.path.append(os.path.abspath(recorder_lib_path))
from recorder import preview_capture, record_live, record_video, write_frame, vid_array_from_npy_folder, reconstruct_video,  unpack_capture_chunks

"""Parse arguments via the command line"""
def parse_args() -> tuple:
    parser = argparse.ArgumentParser(description='Record videos from the pupil labs camera')
    
    parser.add_argument('output_path', type=str, help='Path to output the recorded video to (including .avi file extension)') 
    parser.add_argument('duration', type=float, help='Duration of the video')
    parser.add_argument('--save_video', default=0, type=int, help='Choose whether to actually save the video or not')
    parser.add_argument('--save_frames', default=0, type=int, help='Choose whether or not to save frames of a video after finished recording')
    parser.add_argument('--preview', default=0, type=int, help='Display a preview of the view of the camera before capturing')
    parser.add_argument('--unpack_frames', default=0, type=int, help='Unpack the buffers of frames files into single frame files or not')
   
    args = parser.parse_args()
    
    return args.output_path, args.duration, bool(args.save_video), bool(args.save_frames), bool(args.preview), bool(args.unpack_frames)

"""If we receive a SIGTERM, terminate gracefully via keyboard interrupt"""
def handle_sigterm(signum, frame):
    print("Received SIGTERM. Raising KeyboardInterrupt...")
    raise KeyboardInterrupt
signal.signal(signal.SIGTERM, handle_sigterm)

def main():
    output_path, duration, save_video, save_frames, preview, unpack_frames = parse_args()

    # If the preview is true, view a preview of the camera view before capture
    if(preview is True):
        preview_capture()
    
    # Select whether to use the set-duration video recorder or the live recorder
    recorder: object = record_live if duration == float('INF') else record_video

    # Retrieve the experiment filename and the video extension
    filename, extension = os.path.splitext(output_path) 

    # Initialize a queue for frames to write 
    write_queue: queue.Queue = queue.Queue()

    # Create a threading flag to declare when to stop indefinite videos
    stop_flag: threading.Event = threading.Event()

    # Build thread processes for both capturing frames and writing frames 
    capture_thread: threading.Thread = threading.Thread(target=recorder, args=(duration, write_queue, 
                                                                               filename, stop_flag))
    write_thread: threading.Thread = threading.Thread(target=write_frame, args=(write_queue, filename))
    
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
        # Then wait for the write thread to complete
        for thread in (capture_thread, write_thread):
            thread.join()

    print('Capture/Write processes finished')

    # Unpack the frame buffers into individual frame files 
    if(unpack_frames is True):
        print('Unpacking pupil frame chunks chunks...')
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