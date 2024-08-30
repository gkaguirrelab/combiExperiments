import matplotlib.pyplot as plt
from natsort import natsorted
import seaborn as sns
import numpy as np
import os 
import cv2

"""Find the pixels activated by a given stimulus video"""
def find_active_pixels(path_to_vid: str):
    # Read in the frame series as a np.array
    vid_arr: np.array = np.array([cv2.imread(os.path.join(path_to_vid, frame)) 
                                  for frame in natsorted(os.listdir(path_to_vid))])

    # Find the avg pixel intensity of each pixel across the video
    # just take the first element to be activity, as they should be 
    # grayscale bayers images
    avg_pixel_activity: np.array = np.mean(vid_arr, axis=0)[:,:,0]

    # Splice out a section of the image to illustrate activity
    example_subset = avg_pixel_activity[:24, :24]

    # Display the activity of each pixel
    plt.title(f'Avg Pixel Activity: {os.path.basename(path_to_vid)}')
    plt.ylabel('Row')
    plt.xlabel('Col')
    plt.xticks(fontsize=4)  # Change x-tick font size
    plt.yticks(fontsize=4)  # Change y-tick font size
   
    sns.heatmap(example_subset, annot=True, cmap='viridis', cbar=True)

    # Show the heatmap
    plt.show()

"""Downsample a bayers image by a factor of 2 along each dimension"""
def downsample(img: np.array) -> np.array:
    import ctypes

    # Find the compiled shared cpp library 
    cwd, filename = os.path.split(os.path.abspath(__file__))
    downsample_cpp_path = os.path.join(cwd, 'downsample.so')
    
    # Read in the cpp downsampling library and define its
    # arguments' types and return type 
    downsample_lib = ctypes.CDLL(downsample_cpp_path) 
    downsample_lib.downsample.argtypes = [ctypes.POINTER(ctypes.c_uint8), 
                                          ctypes.c_uint16, 
                                          ctypes.c_uint16]
    downsample_lib.downsample.restype = ctypes.POINTER(ctypes.c_uint8)

    # Retrieve the downsampled image
    new_shape: np.array = np.array(img.shape)//2
    downsampled_ptr = downsample_lib.downsample(img.flatten().ctypes.data_as(ctypes.POINTER(ctypes.c_uint8)), 
                                                                                               img.shape[0], img.shape[1]); 
    # Copy to np.array
    downsampled: np.array = np.ctypeslib.as_array(downsampled_ptr, shape=new_shape).astype(np.uint8)
    
    # Free the dynamically allocated memory
    downsample_lib.free(downsampled_ptr)

    # Return the downsampled image
    return downsampled


def main():
    path_to_vid = '/Users/zacharykelly/Documents/MATLAB/projects/combiExperiments/code/lightLogger/camera/downsample_lib/tests/green_video'
    sample_frame = cv2.imread(os.path.join(path_to_vid, os.listdir(path_to_vid)[0]))[:,:,0]

    print(f'Dimensions before: {sample_frame.shape}')
    
    plt.imshow(sample_frame, cmap='gray')
    plt.show()

    downsampled = downsample(sample_frame.copy())

    print(f"Dimensions after downsampling: {downsampled.shape}")

    plt.imshow(downsampled, cmap='gray')

    plt.show()

if(__name__ == '__main__'):
    main()