import os
import numpy as np
from utility.MS_util import reading_to_df, reading_to_np

# Communicate with the MiniSpect
def MS_com():
    AS_df = reading_to_df('./readings/MS/AS_channels.csv', np.float32)

    print(LI_df.head)

def main():
    MS_com()

if(__name__ == '__main__'):
    main()