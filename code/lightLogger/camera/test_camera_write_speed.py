import sys
import numpy as np
import time
import os

"""Append the path to the world camera recorder"""
world_camera_recorder_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'camera')
sys.path.append(os.path.abspath(world_camera_recorder_path))
import recorder

def main():
    # Initialize the picamera object
    cam: object = recorder.initialize_camera()

    # Initialize n frames and size
    n_frames: int = 200 * 60
    frame_size: tuple = [480, 640]

    # Create a sample output 
    sample_output_path: str = '/media/rpiControl/EXTERNAL1/write_speed_test'
    sample_writeval: np.array = np.full((n_frames, *frame_size), 100, dtype=np.uint8)

    # Create the output dir
    if(not os.path.exists(sample_output_path)): os.mkdir(sample_output_path)

    # Begin timing and write the frames
    start_time: float = time.time()
    for i in range(sample_writeval.shape[0]):
        np.save(os.path.join(sample_output_path, f'frame{i}.npy'), sample_writeval[i])

    # Finish timing
    end_time: float = time.time()

    # Calculate total time to write 
    elapsed_time: float = end_time - start_time

    # Calculate time per frame 
    time_per_frame: float = elapsed_time / sample_writeval.shape[0]

    print(f'Total elapsed time: {elapsed_time}s')
    print(f'Time per frame (n={sample_writeval.shape[0]}): {time_per_frame}s')



if(__name__ == '__main__'):
    main()