import os
import numpy as np
import asyncio
from utility.MS_util import read_MSBLE, parse_MSBLE, write_data
import argparse

def parse_args() -> str:
    parser = argparse.ArgumentParser(description='Communicate to the MS and read/write its data')

    parser.add_argument('device_id', type=str, help='UUID available via finding the device on NRF connect.\nExample:  UUID: str = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"')

    args = parser.parse_args()

    return args.device_id

async def main():
    # Retrieve the name of the device to connect with
    id: str = parse_args()

    # Initialize output directory and names 
    # of reading files
    output_directory: str = './readings/MS'
    reading_names: list = ['AS_channels','TS_channels',
                         'LI_channels','LI_temp']

    # If the output directory does not exist, make it
    if(not os.path.exists(output_directory)): os.mkdir(output_directory)

    # Initialize asynchronous read/write queues 
    read_queue = asyncio.Queue()
    write_queue = asyncio.Queue()

    # Create reading, parsing, and writing asynchronous tasks 
    read_task = asyncio.create_task(read_MSBLE(read_queue, id))
    parse_task = asyncio.create_task(parse_MSBLE(read_queue, write_queue))
    write_task = asyncio.create_task(write_data(write_queue, reading_names, output_directory))

    # Perform tasks
    await asyncio.gather(read_task, parse_task, write_task, return_exceptions=True)

if(__name__ == '__main__'):
    asyncio.run(main())