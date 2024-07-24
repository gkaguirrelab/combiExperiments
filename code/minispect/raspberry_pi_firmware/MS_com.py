import os
import numpy as np
from utility.MS_util import reading_to_df, reading_to_np, plot_channel, \
                            unpack_accel_df
import matplotlib.pyplot as plt
import matplotlib.dates as mdates

# Communicate with the MiniSpect
def MS_com():
    # Gather and parse the reading files
    AS_df = reading_to_df('./readings/MS/AS_channels.csv', np.uint16)
    TS_df = reading_to_df('./readings/MS/TS_channels.csv', np.uint16)
    LI_df = unpack_accel_df(reading_to_df('./readings/MS/LI_channels.csv', np.int16))
    LI_temp_df = reading_to_df('./readings/MS/LI_temp.csv', np.float32)
    
    # Associate chip names to their respective DataFrames
    chip_df_map = {name:df for name, df in zip(['AS','TS','LI','LI_temp'], [AS_df, TS_df, LI_df, LI_temp_df])}

    # Create a 2x2 figure to display the respective plots on
    fig, axes = plt.subplots(2,2, figsize=(10,6))
    axes = np.reshape(axes,(axes.shape[0]*axes.shape[1]))
    plt.subplots_adjust(wspace=0.4, hspace=0.4)

    # Plot the data frames onto their respective axes 
    for (name, df), ax in zip(chip_df_map.items(), axes):
        for channel in df.columns[1:]:
            plot_channel(df['Timestamp'], df[channel], f"{name}_" + channel, ax)
    
    # Label the Count Value plots
    for name, ax in zip(list(chip_df_map.keys())[:2], axes[:2]):
        ax.set_xlim([df['Timestamp'].min(), df['Timestamp'].max()])
        ax.tick_params(axis='x', labelsize=6)
        ax.set_xlabel('Time')
        ax.set_ylabel('Count Value')
        ax.set_title(f'{name} Count Value by Time (0.1Hz flicker)')
        ax.legend(loc='best',fontsize='small')

    # Label the Acceleration and Temperature Plots
    for title, (name,df), ax in zip(['Acceleration by Time', 'Temperature by Time'], chip_df_map.items(), axes[2:]):
        y_label, x_label = title.split(' ')[0:3:2]
        
        ax.set_xlim([df['Timestamp'].min(), df['Timestamp'].max()])
        ax.tick_params(axis='x', labelsize=6)
        ax.set_xlabel(x_label)
        ax.set_ylabel(y_label)
        ax.set_title(f'{y_label} by {x_label} (0.1Hz flicker)')
        ax.legend(loc='best',fontsize='small')

    # Display the plot 
    plt.show() 


def main():
    MS_com()

if(__name__ == '__main__'):
    main()