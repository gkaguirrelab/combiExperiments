import matplotlib.pyplot as plt
from natsort import natsorted
import seaborn as sns
import numpy as np
import os 
import ctypes
import cv2

"""A generalized bayer downsample algorithm written in pure Python
   Note: factor is a power of two. So factor=1 downscales by 2 along
   dimension"""
def downsample_pure_python(img: np.array, factor: int) -> np.array:
    # Initialize downscaled img full of unsigned 8 bit ints of shape 
    # img.shape divided by 2 * factor
    downsampled_shape: np.array = np.array(img.shape) >> factor
    downsampled_img: np.array = np.zeros(downsampled_shape, dtype=np.uint8)

    # Initialize the indices to insert the new pixels into
    downsampled_r = downsampled_c = 0 

    # Initialize the size of chunks
    chunk_size: int = 2 << factor

    # Iterate over the original image
    for r in range(0, img.shape[0], chunk_size):
        # Set the downsampled col back to 0 for this block
        downsampled_c = 0 

        # Iterate over the horizontal chunks
        for c in range(0, img.shape[1], chunk_size):
            # Find the pixels of each color
            r_pixels: np.array = img[r+1:r+chunk_size:2, c+1:c+chunk_size:2] 
            b_pixels: np.array = img[r:r+chunk_size:2, c:c+chunk_size:2] 
            gr_pixels: np.array = img[r+1:r+chunk_size:2, c:c+chunk_size:2] 
            gb_pixels: np.array = img[r:r+chunk_size:2, c+1:c+chunk_size:2] 

            # Take the mean of those pixels and assign it to the insertion location
            downsampled_img[downsampled_r+1,downsampled_c+1] = np.mean(r_pixels)
            downsampled_img[downsampled_r, downsampled_c] = np.mean(b_pixels)
            downsampled_img[downsampled_r+1, downsampled_c] = np.mean(gr_pixels)
            downsampled_img[downsampled_r, downsampled_c+1] = np.mean(gb_pixels)

            # Incrememnt the horizontal chunk to insert in the downsampled img
            downsampled_c += 2
        
        # Increment the vertical chunk to insert in the downsampled img
        downsampled_r += 2

    # Return the downsampled image
    return downsampled_img

"""Import the necessary libraries to use the CPP downsampling library.
    This is time consuming, so don't do if we don't have to."""
def import_downsample_lib() -> ctypes.CDLL:
    # Find the compiled shared cpp library 
    cwd, filename = os.path.split(os.path.abspath(__file__))
    downsample_cpp_path = os.path.join(cwd, 'downsample.so')

    # Read in the cpp downsampling library and define its
    # arguments' types and return type 
    downsample_lib = ctypes.CDLL(downsample_cpp_path) 
    downsample_lib.downsample.argtypes = [  ctypes.POINTER(ctypes.c_uint8), 
                                            ctypes.c_uint16, 
                                            ctypes.c_uint16]
    downsample_lib.downsample.restype = ctypes.POINTER(ctypes.c_uint8)

    return downsample_lib

"""A generalized bayer downsample algorithm written in CPP called by Python
   Note: factor is a power of two. So factor=1 downscales by 2 along
   dimension"""
def downsample(img: np.array, factor: int, lib: ctypes.CDLL=None) -> np.array:
    # Import the downsample library if we need to. Note, this is very time consuming
    if(lib is None): lib = import_downsample_lib()
    
    # Retrieve the downsampled image
    new_shape: np.array = np.array(img.shape) >> factor
    downsampled_ptr = lib.downsample(img.flatten().ctypes.data_as(ctypes.POINTER(ctypes.c_uint8)), 
                                                img.shape[0], img.shape[1]); 
    downsampled: np.array = np.ctypeslib.as_array(downsampled_ptr, shape=new_shape).astype(np.uint8)
    
    # Free the dynamically allocated memory
    lib.free(downsampled_ptr)

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