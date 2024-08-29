import matplotlib.pyplot as plt
from natsort import natsorted
import seaborn as sns
import numpy as np
import os 
import cv2

"""Find the pixels activated by a given stimulus video"""
def find_active_pixels(path_to_vid: str, disp: bool=False):
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

def main():
    path_to_vid = '/Users/zacharykelly/Documents/MATLAB/projects/combiExperiments/code/lightLogger/camera/binning_lib/tests/green_video'
    find_active_pixels(path_to_vid, True)

if(__name__ == '__main__'):
    main()