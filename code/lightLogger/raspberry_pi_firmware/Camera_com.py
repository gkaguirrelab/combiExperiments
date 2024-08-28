# Import public libraries
import sys
import threading
import queue
import argparse
import os
import shutil
import numpy as np

"""Import utility functions from the RPI recorder"""
recorder_lib_path = os.path.join(os.path.dirname(__file__), '..', 'camera')
sys.path.append(os.path.abspath(recorder_lib_path))
from recorder import record_video, write_frame, vid_array_from_file, reconstruct_video

"""Parse arguments via the command line"""
def parse_args() -> tuple:
    parser = argparse.ArgumentParser(description='Record videos from the camera via the RP')
    
    parser.add_argument('output_path', type=str, help='Path to output the recorded video to (including .avi file extension)') 
    parser.add_argument('duration', type=float, help='Duration of the video')
    parser.add_argument('--save_video', default=0, type=int, help='Choose whether to actually save the video or not')
    parser.add_argument('--save_frames', default=0, type=int, help='Choose whether or not to save frames of a video after finished recording')
    parser.add_argument('--initial_gain', default=1.0, type=float, help='Gain value with which to initialize the camera')
    parser.add_argument('--initial_exposure', default=1000, type=int, help='Exposure value with which to initialize the camera')
   
    args = parser.parse_args()
    
    return args.output_path, args.duration, args.initial_gain, args.initial_exposure, bool(args.save_video), bool(args.save_frames)

def camera_live(output_path: str, 
               duration: float, 
               initial_gain: float, 
               initial_exposure: int, 
               save_video: bool,
               save_frames: bool):
    
    # Retrieve the experiment filename and the video extension
    filename, extension = os.path.splitext(output_path) 

    # Initialize a queue for frames to write 
    write_queue: queue.Queue = queue.Queue()
    
    # Build thread processes for both capturing frames and writing frames 
    capture_thread: threading.Thread = threading.Thread(target=record_video, args=(duration, write_queue, filename, initial_gain, initial_exposure))
    write_thread: threading.Thread = threading.Thread(target=write_frame, args=(write_queue, filename))
    
    # Begin the threads
    for thread in (capture_thread, write_thread):
        thread.start()
    
    # Join the threads when they have completed
    for thread in (capture_thread, write_thread):
        thread.join()
    
    print('Capture/Write processes finished')

    # Construct and save a video by the given filename and extension 
    # if desired
    if(save_video is True):
        print('Generating video...')
        frames: np.array = vid_array_from_file(filename)
        reconstruct_video(frames, output_path)
    
    # Remove the directory of frames if desired
    if(save_frames is not True): shutil.rmtree(filename)


def main():
    output_path, duration, initial_gain, initial_exposure, save_video, save_frames = parse_args()
    
    # Retrieve the experiment filename and the video extension
    filename, extension = os.path.splitext(output_path) 

    # Initialize a queue for frames to write 
    write_queue: queue.Queue = queue.Queue()

    # Build thread processes for both capturing frames and writing frames 
    capture_thread: threading.Thread = threading.Thread(target=record_video, args=(duration, write_queue, filename, initial_gain, initial_exposure))
    write_thread: threading.Thread = threading.Thread(target=write_frame, args=(write_queue, filename))
    
    # Begin the threads
    for thread in (capture_thread, write_thread):
        thread.start()
    
    # Join the threads when they have completed
    for thread in (capture_thread, write_thread):
        thread.join()
    
    print('Capture/Write processes finished')

    # Construct and save a video by the given filename and extension 
    # if desired
    if(save_video is True):
        print('Generating video...')
        frames: np.array = vid_array_from_file(filename)
        reconstruct_video(frames, output_path)
    
    # Remove the directory of frames if desired
    if(save_frames is not True): shutil.rmtree(filename)
    

    


if(__name__ == '__main__'):
    main()
