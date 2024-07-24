import numpy as np
import asyncio
import sys
from itertools import count, takewhile
from typing import Iterator
from bleak import BleakClient, BleakScanner
from bleak.backends.characteristic import BleakGATTCharacteristic
from bleak.backends.device import BLEDevice
from bleak.backends.scanner import AdvertisementData
import os
from datetime import datetime
import pandas as pd
import matplotlib.pyplot as plt

def unpack_accel_df(df) -> pd.DataFrame:
    # Define the columns and their types for the new dataframe 
    # with accel buffer unpacked
    columns: list = ['Timestamp', 'X', 'Y', 'Z']
    types: list = ['datetime64[ns]'] + [np.int32 for i in range(3)]
    
    # Create the new dataframe
    new_df: pd.DataFrame = pd.DataFrame(columns=columns)
    new_df = new_df.astype({col:type_ for col, type_ in zip(columns, types)})

    # Extract the times we actually measured,
    # and prepare new col for unpacked times 
    measured_times = df['Timestamp'].tolist()
    unpacked_times = []

    # Retrieve all of the cols for a given axis
    X_cols = [col for col in df.columns if 'X' in col]
    Y_cols = [col for col in df.columns if 'Y' in col]
    Z_cols = [col for col in df.columns if 'Z' in col]

    # Concat all of the axes measurements' 
    # over the buffers 
    x = pd.concat([df.loc[i, X_cols] for i in range(df.shape[0])], ignore_index=True)
    y = pd.concat([df.loc[i, Y_cols] for i in range(df.shape[0])], ignore_index=True)
    z = pd.concat([df.loc[i, Z_cols] for i in range(df.shape[0])], ignore_index=True)

    # Retrieve the buffer size, ie, how many of a given 
    # axis do we have per a single reading
    buffer_size = len(X_cols)
    
    # Unpack the first buffer, the one which we do not have a start_time for 
    unpacked_times.extend(pd.date_range(end=measured_times[0], periods=buffer_size, inclusive='both'))

    # Otherwise, fill the gaps in the time with linearly spaced values
    for i in range(1,len(measured_times)):
        start_time = measured_times[i-1]
        end_time = measured_times[i]
                                                            # there should be BUFFER_SIZE values between existing points
        unpacked_times.extend(pd.date_range(start=start_time, end=end_time, periods=buffer_size+1,inclusive='right'))

    # Package the reformatted measurements 
    reformatted_measurements = [unpacked_times,x,y,z]

    # Assert they are all of equal length (ie, did the unpacking go correctly)
    assert all(len(reformatted_measurements[i]) == len(reformatted_measurements[i+1]) for i in range(len(reformatted_measurements)-1))

    # Fill in the new dataframe with the concatenated values
    for name, measurement in zip(columns, reformatted_measurements):
        new_df[name] = measurement

    
    return new_df





# Plot a channel from a df with a given label
def plot_channel(x: pd.Series, channel : pd.Series, label: str, ax: plt.Axes):
    ax.plot(x, channel, marker='o', markersize=2, label=label)

# Parse a reading csv and return the resulting dataframe 
# with labeled cols
def reading_to_df(reading_path: str, channel_type : type) -> pd.DataFrame:
    # Read in the csv from the given path
    df: pd.DataFrame = pd.read_csv(reading_path,sep=',',header=None)

    # Create an axis mapping for the indices of a given accelerometer
    # reading
    accel_mapping = {i:let for i, let in zip([0,1,2],['X','Y','Z'])}
    
    # Form column names and their associated types              # col_i if not LI_channels, otherwise use the mapping to parse            
    columns : list = ['Timestamp'] + [str(i) if 'LI_channels' not in reading_path else f"{accel_mapping[i%3]}{int(i/3)}" for i in range(df.shape[1]-1)]
    types :list = ['datetime64[ns]'] + [channel_type for i in range(df.shape[1]-1)]
    
    # Reformat the DataFrame with col names and types
    df.columns = columns 
    df = df.astype({col:type_ for col, type_ in zip(columns, types)})

    # Return the DataFrame
    return df

# Parse a reading csv and return the resulting dataframe 
# as a np.array
def reading_to_np(reading_path: str, channel_type: type) -> np.array:
    
    # Parse as DataFrame and convert to numpy array
    return reading_to_df(reading_path, channel_type).to_numpy()

# Convert the numpy array of a chip's reading 
# to a storable string
def reading_to_string(read_time: datetime, reading: np.array) -> str:
    
    # Intersperse , between all channel values as str
    # and add new line
    return ",".join([str(read_time)] + [str(x) for x in reading]) + '\n'


async def write_data(write_queue: asyncio.Queue, reading_names: list[str], output_directory: str):
    try:
        while True:
            readings = await write_queue.get()

            print(f'Writing: {readings}')

            read_time = readings[0]
            # Create mapping between filenames and readings 
            # from the Minispect
            results_mapping: dict = {reading_name:reading for reading_name, 
                            reading in zip(reading_names,readings[1:])}

            # Iterate over the reading names/readings
            for reading_name, reading in results_mapping.items():
                # Display how much information is in each reading
                #print(f"Reading: {reading_name} | Shape: {reading.shape}")

                # Path for this reading's data file
                save_path: str = os.path.join(output_directory, reading_name + '.csv')

                # Open file, append new reading to the end
                with open(save_path,'a') as f:
                    f.write(reading_to_string(read_time,reading))
        
    except Exception as e:
        print(e)

# Parse the bytes read over bluetooth 
# from the MiniSpect
async def parse_MSBLE(read_queue: asyncio.Queue, write_queue: asyncio.Queue): 
    try:
        while True:
            # Retrieve the latest bytes received 
            read_time, bluetooth_bytes = await read_queue.get()

            print(f"Parsing: {bluetooth_bytes}")

            # Splice and convert the channels to their respective types 
            AS_channels: np.array = np.frombuffer(bluetooth_bytes[2:24],dtype=np.uint16)
            TS_channels: np.array = np.frombuffer(bluetooth_bytes[24:28],dtype=np.uint16)
            LI_channels: np.array = np.frombuffer(bluetooth_bytes[28:148],dtype=np.int16)
            LI_temp = np.array = np.frombuffer(bluetooth_bytes[148:152],dtype=np.float32)

            # Add them in the queue of values to write
            await write_queue.put([read_time,AS_channels,TS_channels,LI_channels,LI_temp])
    
    except Exception as e:
        print(e)

# TIP: you can get this function and more from the ``more-itertools`` package.
def sliced(data: bytes, n: int) -> Iterator[bytes]:
    """
    Slices *data* into chunks of size *n*. The last slice may be smaller than
    *n*.
    """
    return takewhile(len, (data[i : i + n] for i in count(0, n)))

# Read bytes from the MiniSpect 
# over bluetooth via the UART
# example from the bleak librray
async def read_MSBLE(queue: asyncio.Queue):

    UART_SERVICE_UUID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
    UART_RX_CHAR_UUID = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
    UART_TX_CHAR_UUID = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

    def match_nus_uuid(device: BLEDevice, adv: AdvertisementData):
        # This assumes that the device includes the UART service UUID in the
        # advertising data. This test may need to be adjusted depending on the
        # actual advertising data supplied by the device.
        if UART_SERVICE_UUID.lower() in adv.service_uuids:
            return True

        return False

    device = await BleakScanner.find_device_by_name("LightSense1",timeout=30) # find_device_by_filter(match_nus_uuid,timeout=30)

    if device is None:
        print("no matching device found, you may need to edit match_nus_uuid().")
        sys.exit(1)

    def handle_disconnect(_: BleakClient):
        print("Device was disconnected, goodbye.")
        # cancelling all tasks effectively ends the program
        for task in asyncio.all_tasks():
            task.cancel()

    async def handle_rx(_: BleakGATTCharacteristic, data: bytearray):
        current_time = datetime.now()
        print(f"received [{len(data)}]:", data)
        await queue.put([current_time, data])

    async with BleakClient(device, disconnected_callback=handle_disconnect) as client:
        # Start notifications for receiving data
        await client.start_notify(UART_TX_CHAR_UUID, handle_rx)

        print("Connected, now reading data...")
        loop = asyncio.get_running_loop()
        nus = client.services.get_service(UART_SERVICE_UUID)
        rx_char = nus.get_characteristic(UART_RX_CHAR_UUID)

        while True:
            # This waits until you type a line and press ENTER.
            # A real terminal program might put stdin in raw mode so that things
            # like CTRL+C get passed to the remote device.
            data = await loop.run_in_executor(None, sys.stdin.buffer.readline)

            # data will be empty on EOF (e.g. CTRL+D on *nix)
            if not data:
                break

            # some devices, like devices running MicroPython, expect Windows
            # line endings (uncomment line below if needed)
            # data = data.replace(b"\n", b"\r\n")

            # Writing without response requires that the data can fit in a
            # single BLE packet. We can use the max_write_without_response_size
            # property to split the data into chunks that will fit.

            for s in sliced(data, rx_char.max_write_without_response_size):
                await client.write_gatt_char(rx_char, s, response=False)

            print("sent:", data)
    

async def main():
    output_directory: str = './readings/MS'
    reading_names: list = ['AS_channels','TS_channels',
                         'LI_channels','LI_temp']
    
     # If the output directory does not exist,
        # make it
    if(not os.path.exists(output_directory)):
        os.mkdir(output_directory)
    
    read_queue = asyncio.Queue()
    write_queue = asyncio.Queue()

    read_task = asyncio.create_task(read_MSBLE(read_queue))
    parse_task = asyncio.create_task(parse_MSBLE(read_queue, write_queue))
    write_task = asyncio.create_task(write_data(write_queue, reading_names, output_directory))

    #await asyncio.gather(read_task,return_exceptions=True)
    await asyncio.gather(read_task, parse_task, write_task, return_exceptions=True)

if(__name__ == '__main__'):
    asyncio.run(main())