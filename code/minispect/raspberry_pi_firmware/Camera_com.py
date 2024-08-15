from utility.Camera_util import record_video, write_frame, vid_array_from_file, reconstruct_video
import threading
import queue
import argparse
import os
import shutil

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
    
    capture_thread = threading.Thread(target=record_video, args=(duration, write_queue))
    write_thread = threading.Thread(target=write_frame, args=(write_queue, filename))
    

    for thread in (capture_thread, write_thread):
        thread.start()
        
    for thread in (capture_thread, write_thread):
        thread.join()
    
    print('Capture/Write processes finished')
    
    print('Generating video...')
    frames = vid_array_from_file(filename)
    reconstruct_video(frames, output_path)
    shutil.rmtree(filename)
    
    
    print('Video output')
    

    


if(__name__ == '__main__'):
    main()
