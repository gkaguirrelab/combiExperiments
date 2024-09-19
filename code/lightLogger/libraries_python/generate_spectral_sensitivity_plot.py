import numpy as np
import pandas as pd
from scipy import interpolate
import matplotlib.pyplot as plt


"""Generate a spectral sensitivity plot from an image of one
Step 1: Go to https://automeris.io/wpd/?v=5_2 
and generate csv's of points on the curve.
These are the point file inputs"""
def generate_spectral_sensitivity_plot(channel_points_paths: list, rescale_range: tuple) -> pd.DataFrame:
    # Initialize a list to hold the cvs after they are read in as pd.DataFrames 
    channel_dfs: list = [pd.read_csv(path, names=['X', 'Y']) 
                        for path in channel_points_paths]

    # Create the new x coordinates (note, this might change for the range of the plot you've generated)
    new_min, new_max, dx = rescale_range
    new_x: np.array = np.arange(new_min, new_max, dx)
    
    # Create a dictionary to hold y values after conversion
    results: dict = {'wl': new_x}

    for channel_num, df in enumerate(channel_dfs):
        # Rescale the x coordinates
        rescaled_x: pd.Series = new_min + (df['X'] - np.min(df['X'])) * (new_max - new_min) / (np.max(df['X']) - np.min(df['X']))

        # Fit the function
        f = interpolate.interp1d(rescaled_x, df['Y'], kind='cubic')

        # Calculate the new y vector including the interpolated points
        new_y: np.array = f(new_x)

        # Save these new y values for the associated channel
        results[f"CH{channel_num}"] = new_y

        # Plot this curve
        plt.plot(new_x, new_y, label=f'Channel {channel_num}')

    # Join the channels together into a new DataFrame
    joined_df: pd.DataFrame = pd.DataFrame(results)

    # Plot the resulting curves
    plt.title('Generated Spectral Sensitivty Plot')
    plt.ylabel('Responsivity')
    plt.xlabel('Wavelength [mm]')
    plt.legend()
    plt.show()

    # Return the joined dataframe 
    return joined_df



def main():
    generate_spectral_sensitivity_plot()

if(__name__ == '__main__'):
    main()