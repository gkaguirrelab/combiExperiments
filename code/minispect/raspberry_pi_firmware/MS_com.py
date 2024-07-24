import os
import numpy as np
from utility.MS_util import reading_to_df, reading_to_np, plot_channel
import matplotlib.pyplot as plt

# Communicate with the MiniSpect
def MS_com():
    AS_df = reading_to_df('./readings/MS/AS_channels.csv', np.uint16)
    TS_df = reading_to_df('./readings/MS/TS_channels.csv', np.uint16)
    
    fig, (ax1, ax2) = plt.subplots(2,1, figsize=(10,6))

    for channel in AS_df.columns[1:]:
        plot_channel(AS_df['Timestamp'], AS_df[channel], 'AS_' + channel, ax1)
    
    for channel in TS_df.columns[1:]:
        plot_channel(TS_df['Timestamp'], TS_df[channel], 'TS_' + channel, ax2)

    for ax in (ax1,ax2):
        ax.set_xlabel('Time')
        ax.set_ylabel('Count Value')
        ax.set_title('Count Value by Measurement (2Hz flicker)')
        ax.legend(loc='best',fontsize='small')
    
    plt.show()


def main():
    MS_com()

if(__name__ == '__main__'):
    main()