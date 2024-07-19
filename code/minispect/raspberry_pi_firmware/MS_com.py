import os
import numpy as np
from utility.MS_util import read_MSBLE
from utility.MS_util import parse_MSBLE

# Communicate with the MiniSpect
def MS_com():
    # Path to output data to
    # and names of data files
    output_path:str = 'readings/MS'
    reading_names:list = ['AS_channels','TS_channels',
                         'LI_channels',]
    
    # Read/Parse bytes over BLE from MiniSpect
    bluetooth_bytes:list = read_MSBLE()
    readings:list = parse_MSBLE(bluetooth_bytes)

    # Create mapping between filenames and readings 
    # from the Minispect
    results_mapping:dict = {reading_name:reading for reading_name, 
                       reading in zip(reading_names,readings)}

    # If the output directory does not exist,
    # make it
    if(not os.path.exists(output_path)):
        os.mkdir(output_path)
    
    # Iterate over the reading names/readings
    for reading_name, reading in results_mapping.items():
        
        # Path for this reading's data file
        save_path:str = os.path.join(reading_name,'.npy')

        # If the data file doesn't exist already, 
        # create it and go onto the next ones
        if(not os.path.exists(save_path)):
            np.save(save_path,reading)
            continue
        
        # Otherwise, load the existing data in
        # and concatenate the newly acquired data 
        # to it
        existing_data:np.array = np.load(save_path)
        existing_data = np.concatenate((existing_data,reading),axis=0)

        # Re-save the data
        np.save(save_path,existing_data)

def main():
    MS_com()

if(__name__ == '__main__'):
    main()