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
                                            ctypes.c_uint16,
                                            ctypes.c_uint8,
                                            ctypes.POINTER(ctypes.c_uint8)]


    return downsample_lib

"""A generalized bayer-aware downsample algorithm written in CPP called by Python
   Note: factor is a power of two. So factor=1 downscales by 2 along
   dimension. Populates output_memory_buffer with the downsampled image. 
   Should be the size of the image downsampled by the factor and an 
   np.empty of dtype np.uint8"""
def downsample(img: np.ndarray, factor: int, output_memory_buffer: np.ndarray, lib: ctypes.CDLL=None) -> None:
    # Import the downsample library if we need to. Note, this is very time consuming
    if(lib is None): lib = import_downsample_lib()
    
    # Retrieve the shape of the image
    height, width = img.shape[0], img.shape[1]
    new_height, new_width = height >> factor, width >> factor 
    
    # Downsample the image and populate the buffer
    lib.downsample(img.ctypes.data_as(ctypes.POINTER(ctypes.c_uint8)), 
                   height, width,
                   factor,
                   output_memory_buffer.ctypes.data_as(ctypes.POINTER(ctypes.c_uint8))); 

"""A generalized bayer-aware downsample algorithm written in CPP called by Python
   Note: factor is a power of two. So factor=1 downscales by 2 along
   dimension. Populates output_memory_buffer with a buffer of downsampled images. 
   Should be the the number of frames, then the size of the image downsampled by 
   the factor and an np.empty of dtype np.uint8"""
def downsample_buffer(img_buffer: np.ndarray, buffer_size: int, factor: int, output_memory_buffer: np.ndarray, lib: ctypes.CDLL=None) -> None:    
    # Import the downsample library if we need to. Note, this is very time consuming
    if(lib is None): lib = import_downsample_lib()
    
    # Retrieve the shape of the image
    height, width = img_buffer.shape[1], img_buffer.shape[2]
    new_height, new_width = height >> factor, width >> factor 
    
    # Downsample the image and populate the buffer
    lib.downsample_buffer(img_buffer.ctypes.data_as(ctypes.POINTER(ctypes.c_uint8)), 
                          buffer_size, 
                          height, width,
                          factor,
                          output_memory_buffer.ctypes.data_as(ctypes.POINTER(ctypes.c_uint8))); 

"""Main used for testing purposes"""
def main():
    # Define a path to a video 
    path_to_vid: str = '/Volumes/EXTERNAL1/120fps_5hz_0NDF/120fps_5hz_0NDF_world'
    
    # Read in the first frame buffer
    first_frame_buffer: np.ndarray = np.load(os.path.join(path_to_vid, '120.npy'))

    # Retrieve a sample frame 
    sample_frame: np.ndarray = first_frame_buffer[0]

    print(f'Dimensions before: {sample_frame.shape}')

    # Import the CPP downsamplig lib 
    lib = import_downsample_lib()

    downsampled = downsample(sample_frame, 1, lib)

    print(f"Dimensions after downsampling: {downsampled.shape}")

    #plt.imshow(downsampled, cmap='gray')

    #plt.show()

if(__name__ == '__main__'):
    main()  