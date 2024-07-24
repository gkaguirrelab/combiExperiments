import os
import numpy as np
from utility.MS_util import reading_to_df, reading_to_np, plot_channel
import matplotlib.pyplot as plt

# Communicate with the MiniSpect
def MS_com():
    AS_df = reading_to_df('./readings/MS/AS_channels.csv', np.uint16)
    TS_df = reading_to_df('./readings/MS/TS_channels.csv', np.uint16)
    
    for channel in AS_df.columns[1:]:
        plot_channel(AS_df[channel], 'AS_' + channel)
    
    for channel in TS_df.columns[1:]:
        plot_channel(TS_df[channel], 'TS_' + channel)

    plt.xlabel('Measurement')
    plt.ylabel('Count Value')
    plt.title('Count Value by Measurement (2Hz flicker)')
    plt.legend(loc='center')
    plt.show()


def main():
    MS_com()

if(__name__ == '__main__'):
    main()