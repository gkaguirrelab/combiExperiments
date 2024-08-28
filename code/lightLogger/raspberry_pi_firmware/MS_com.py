import os
import numpy as np
import asyncio
from utility.MS_util import read_MSBLE, parse_MSBLE, write_data

async def main():
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
    read_task = asyncio.create_task(read_MSBLE(read_queue))
    parse_task = asyncio.create_task(parse_MSBLE(read_queue, write_queue))
    write_task = asyncio.create_task(write_data(write_queue, reading_names, output_directory))

    # Perform tasks
    await asyncio.gather(read_task, parse_task, write_task, return_exceptions=True)

if(__name__ == '__main__'):
    asyncio.run(main())