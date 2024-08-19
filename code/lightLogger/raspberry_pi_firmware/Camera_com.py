# Import public libraries
import sys
import threading
import queue
import argparse
import os
import shutil

# Import utility functions from the RPI recorder
recorder_lib_path = os.path.join(os.path.dirname(__file__), '..', 'camera')
sys.path.append(os.path.abspath(recorder_lib_path))
from recorder import record_video, write_frame, vid_array_from_file, reconstruct_video

def parse_args():
    parser = argparse.ArgumentParser(description='Record videos from the camera via the RP')
    parser.add_argument('output_path', type=str, help='Path to output the recorded video to') 
    parser.add_argument('duration', type=float, help='Duration of the video')
   
    args = parser.parse_args()
    
    return args.output_path, args.duration

def main():
    output_path, duration = parse_args()
    filename, extension = os.path.splitext(output_path) 

    write_queue = queue.Queue()
    
    capture_thread = threading.Thread(target=record_video, args=(duration, write_queue, filename))
    write_thread = threading.Thread(target=write_frame, args=(write_queue, filename))
    

    for thread in (capture_thread, write_thread):
        thread.start()
        
    for thread in (capture_thread, write_thread):
        thread.join()
    
    print('Capture/Write processes finished')
    
    print('Generating video...')
    frames = vid_array_from_file(filename)
    reconstruct_video(frames, os.path.join(filename, output_path))
    
    print('Video output')

    print('Removing frames...')
    for file in os.listdir(filename):
        if('.pkl' not in file):
            os.remove(os.path.join(filename, file))
    

    


if(__name__ == '__main__'):
    main()
