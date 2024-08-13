from utility.Camera_util import record_video, write_frame, mean_frame_intensity 
import argparse
import multiprocessing as mp
import time
import ctypes


def parseArgs():
    parser = argparse.ArgumentParser(description='Record videos from the camera via the RP')
    parser.add_argument('output_path', type=str, help='Path to output the recorded video to')
    parser.add_argument('duration', type=float, help='Duration of the video')

    args = parser.parse_args()
    
    return args.output_path, args.duration

def main():
    output_path, duration = parseArgs()

    capture_queue = mp.Queue()
    write_queue = mp.Queue() 
    agc_queue = mp.Queue()
    current_settings_queue = mp.Queue()
    future_settings_queue = mp.Queue()
    future_settings_queue.put(None)

    capture_process = mp.Process(target=record_video, args=(output_path, duration,
                                                            capture_queue, write_queue,
                                                            agc_queue,
                                                            current_settings_queue, future_settings_queue))
    write_process = mp.Process(target=write_frame, args=(write_queue,))
    agc_process = mp.Process(target=mean_frame_intensity, args=(agc_queue,
                                                                future_settings_queue))
    
    capture_process.start()
    write_process.start()
    agc_process.start()
    
    while( write_process.is_alive() ):
        time.sleep(1)
        
    for process in (capture_process, write_process, agc_process):
        process.terminate()
        process.join()    
    
    print('Processes finished')



if(__name__ == '__main__'):
    main()