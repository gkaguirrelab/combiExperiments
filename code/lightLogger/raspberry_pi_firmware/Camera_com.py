# Import public libraries
import sys
import threading
import queue
import argparse
import os
import shutil
import numpy as np

# Import utility functions from the RPI recorder
recorder_lib_path = os.path.join(os.path.dirname(__file__), '..', 'camera')
sys.path.append(os.path.abspath(recorder_lib_path))
from recorder import record_video, write_frame, vid_array_from_file, reconstruct_video

def parse_args():
    parser = argparse.ArgumentParser(description='Record videos from the camera via the RP')
    parser.add_argument('output_path', type=str, help='Path to output the recorded video to') 
    parser.add_argument('duration', type=float, help='Duration of the video')
    parser.add_argument('--save_video', default=0, type=int, help='Choose whether to actually save the video or not')
    parser.add_argument('--initial_gain', default=1.0, type=float, help='Gain value with which to initialize the camera')
    parser.add_argument('--initial_exposure', default=37, type=int, help='Gain value with which to initialize the camera')
   
    args = parser.parse_args()
    
    return args.output_path, args.duration, args.initial_gain, args.initial_exposure, bool(args.save_video)

def main():
    output_path, duration, initial_gain, initial_exposure, save_video = parse_args()
    filename, extension = os.path.splitext(output_path) 

    write_queue: queue.Queue = queue.Queue()
    
    capture_thread: threading.Thread = threading.Thread(target=record_video, args=(duration, write_queue, filename, initial_gain, initial_exposure))
    write_thread: threading.Thread = threading.Thread(target=write_frame, args=(write_queue, filename))
    

    for thread in (capture_thread, write_thread):
        thread.start()
        
    for thread in (capture_thread, write_thread):
        thread.join()
    
    print('Capture/Write processes finished')

    if(save_video is True):
        print('Generating video...')
        frames: np.array = vid_array_from_file(filename)
        reconstruct_video(frames, output_path)
    
    shutil.rmtree(filename)
    
    
    print('Video output')
    

    


if(__name__ == '__main__'):
    main()
