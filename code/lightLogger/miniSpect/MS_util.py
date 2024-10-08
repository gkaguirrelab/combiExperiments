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
import queue
import serial
import threading
import time
import collections

"""Generate plots of the readings from the different sensors"""
def plot_readings(path_to_readings: str):
    # Gather and parse the reading files
    AS_df = reading_to_df(os.path.join(path_to_readings, 'AS_channels.csv'), np.uint16)
    TS_df = reading_to_df(os.path.join(path_to_readings, 'TS_channels.csv'), np.uint16)
    LS_df = reading_to_df(os.path.join(path_to_readings, 'LS_channels.csv'), np.int16)
    LS_temp_df = reading_to_df(os.path.join(path_to_readings, 'LS_temp.csv'), np.float32)
    
    # Associate chip names to their respective DataFrames
    chip_df_map = {name:df for name, df in zip(['AS','TS','LS','LS_temp'], [AS_df, TS_df, LS_df, LS_temp_df])}

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
        ax.set_title(f'{name} Count Value by Time')
        ax.legend(loc='best',fontsize='small')

    # Label the Acceleration and Temperature Plots
    for title, (name,df), ax in zip(['Acceleration by Time', 'Temperature by Time'], chip_df_map.items(), axes[2:]):
        y_label, x_label = title.split(' ')[0:3:2]
        
        ax.set_xlim([df['Timestamp'].min(), df['Timestamp'].max()])
        ax.tick_params(axis='x', labelsize=6)
        ax.set_xlabel(x_label)
        ax.set_ylabel(y_label)
        ax.set_title(f'{y_label} by {x_label}')
        ax.legend(loc='best',fontsize='small')

    # Display the plot 
    plt.show() 

"""Reformat the accelerometer DF to be one reading per row of X,Y,Z values
instead of each line having a buffer of values"""
def unpack_accel_df(df) -> pd.DataFrame:
    # Find the buffer size (how many pairs of 3 X,Y,Z values are read for each chip)
    buffer_size: int = collections.Counter([col[0] for col in df.columns])['X'] // 2 

    # Define the names of accelerometer and angle measure axis 
    accelerometer_axes_names: list = ['X', 'Y', 'Z']
    angle_axes_names: list = ['X-ANG', 'Y-ANG', 'Z-ANG']


    # Define the columns and their types for the new dataframe 
    # with accel buffer unpacked
    acceleration_cols: dict = {f"{ax}{i}": None 
                              for ax in accelerometer_axes_names
                              for i in range(buffer_size)}
    
    angular_cols: dict = {f"{ax}{i}": None 
                         for ax in angle_axes_names 
                         for i in range(buffer_size)}

    # Construct the column names of the new dataframe
    columns: list = ['Timestamp'] + accelerometer_axes_names + angle_axes_names

    # Define the types for each column
    types: list = ['datetime64[ns]'] + [np.int16 for col in columns]

    # Extract the times we actually measured,
    # and prepare new col for unpacked times 
    measured_times: list = df['Timestamp'].tolist()
    unpacked_times: list = []

    # Retrieve all of the cols for a given axis
    X_accel_cols: list = [col for col in df.columns 
                         if col in acceleration_cols
                         and col[0] == 'X']
    X_angle_cols: list =  [col for col in df.columns
                         if col in angular_cols
                         and col[0] == 'X']
        
    Y_accel_cols: list = [col for col in df.columns 
                         if col in acceleration_cols
                         and col[0] == 'Y']
    Y_angle_cols: list = [col for col in df.columns
                         if col in angular_cols
                         and col[0] == 'Y']

    Z_accel_cols: list = [col for col in df.columns 
                         if col in acceleration_cols
                         and col[0] == 'Z']
    Z_angle_cols: list = [col for col in df.columns 
                         if col in angular_cols
                         and col[0] == 'Z']

    # Ensure we have correctly extracted all of the buffer column names
    assert(all(len(buff) == buffer_size) for buff in (X_accel_cols, X_angle_cols, Y_accel_cols, Y_angle_cols, Z_accel_cols, Z_angle_cols))

    X_accel: np.ndarray = df[X_accel_cols].to_numpy().flatten()
    X_angle: np.ndarray = df[X_angle_cols].to_numpy().flatten()

    Y_accel: np.ndarray = df[Y_accel_cols].to_numpy().flatten()
    Y_angle: np.ndarray = df[Y_angle_cols].to_numpy().flatten()

    Z_accel: np.ndarray = df[Z_accel_cols].to_numpy().flatten()
    Z_angle: np.ndarray = df[Z_angle_cols].to_numpy().flatten()

    # Define the container to hold the new data frame data
    reformated_measurements: np.ndarray = None

    # If the timestamps are not NA, we need to reconstruct the timestamps to match the 
    # reformatted data
    if(not df['Timestamp'].isna().any()):
        # Unpack the first buffer, the one which we do not have a start_time for 
        unpacked_times.extend(pd.date_range(end=measured_times[0], periods=buffer_size, inclusive='both'))

        # Otherwise, fill the gaps in the time with linearly spaced values
        for i in range(1,len(measured_times)):
            start_time = measured_times[i-1]
            end_time = measured_times[i]
                                                                # there should be BUFFER_SIZE values between existing points
            unpacked_times.extend(pd.date_range(start=start_time, end=end_time, periods=buffer_size+1,inclusive='right'))

        # Package the reformatted measurements 
        reformatted_measurements = [unpacked_times, X_accel, X_angle, Y_accel, Y_angle, Z_accel, Z_angle]

    # Otherwise, simply generate discrete values for the timestamps that are the same length as the df
    else:
        unpacked_times = [pd.NaT] * X_accel.shape[0]
        
        reformatted_measurements = [unpacked_times, X_accel, X_angle, Y_accel, Y_angle, Z_accel, Z_angle ]

    # Format data into column labeled dataframe shape
    data_dict: dict = {col: measurement
                      for col, measurement
                      in zip(columns, reformatted_measurements)}

    # Create the new dataframe
    new_df: pd.DataFrame = pd.DataFrame(data_dict)
    new_df = new_df.astype({col: type_ 
                            for col, type_ 
                            in zip(columns, types)})

    return new_df

"""Plot a channel from a df with a given label"""
def plot_channel(x: pd.Series, channel : pd.Series, label: str, ax: plt.Axes):
    ax.plot(x, channel, marker='o', markersize=2, label=label)

"""Parse a reading csv and return the resulting dataframe with labeled cols"""
def reading_to_df(reading_path: str, channel_type : type) -> pd.DataFrame:
    # Determine if this is the accelerometer readings or not 
    is_accelerometer: bool = os.path.basename(reading_path) == 'LS_channels.csv'

    # Read in the csv from the given path
    df: pd.DataFrame = pd.read_csv(reading_path, sep=',',header=None)

    # Create an axis mapping for the indices of a given accelerometer
    # reading
    LS_accel_mapping = {i:let 
                        for i, let in 
                        zip([0,1,2],['X','Y','Z'])}
    
    LS_angle_mapping = {i:let 
                        for i, let in 
                        zip([0,1,2],['X-ANG','Y-ANG','Z-ANG'])}
    
    # Calculate the size of each of the accelerometer's buffers
    # which is the total number of readings divided by the two buffers
    # divided by the 3 channels
    accel_buffer_size: int = (df.shape[1] - 1) // (2 * 3)
    
    # Form column names and their associated types              # col_i if not accelerometer, 
    #                                                           otherwise use the mapping to parse  
    #                                                           Note: first half of accelerometer cols are accel
    #                                                           other half are angle 
    #                                                                         
    columns : list = ['Timestamp'] + [str(i) 
                                      if is_accelerometer is False
                                      else 
                                        f"{LS_accel_mapping[i%3]}{int(i/3)}" 
                                        if i < (df.shape[1] - 1)/2 
                                            else f"{LS_angle_mapping[i%3]}{int((i/3)-accel_buffer_size)}" 

                                      for i in range(df.shape[1]-1)]

    types :list = ['datetime64[ns]'] + [channel_type for i in range(df.shape[1]-1)]
    
    # Reformat the DataFrame with col names and types
    df.columns = columns 
    df = df.astype({col:type_ for col, type_ in zip(columns, types)})

    # Parse further if necessary 
    df = df if is_accelerometer is False else unpack_accel_df(df)

    # Replace NaN timestamps if necessary 
    if(df['Timestamp'].isna().any()): 
        df['Timestamp'] = list(range(df.shape[0]))

    # Return the DF
    return df 

"""Parse a reading csv and return the resulting dataframe  as a np.array"""
def reading_to_np(reading_path: str, channel_type: type) -> np.array:
    # Parse as DataFrame and convert to numpy array
    return reading_to_df(reading_path, channel_type).to_numpy()

"""Convert the numpy array of a chip's reading 
to a storable string"""
def reading_to_string(read_time: datetime, reading: np.array) -> str:
    # Intersperse , between all channel values as str
    # and add new line
    return ",".join([str(read_time)] + [str(x) for x in reading]) + '\n'

"""Write MS readings taken from the serial connection"""
def write_SERIAL(write_queue: queue.Queue, reading_names: list, output_directory: str):
    while(True):
        print(f'MS Queue size {write_queue.qsize()}')

        # Retrieve an item from the write queue
        ret: tuple = write_queue.get()

        # Break from writing if we have finished a recording
        if(ret is None):
            break
        
        # Otherwise, extract the information from the item
        read_time, bluetooth_bytes = ret

        # Parse the the readings into np.arrays 
        readings: tuple = parse_SERIAL(bluetooth_bytes)

        # Create mapping between filenames and readings 
        # from the Minispect
        results_mapping: dict = {reading_name:reading 
                                for reading_name, reading 
                                in zip(reading_names, readings)}

        # Iterate over the reading names/readings
        for reading_name, reading in results_mapping.items():
            # Path for this reading's data file
            save_path: str = os.path.join(output_directory, reading_name + '.csv')

            # Open file, append new reading to the end
            with open(save_path,'a') as f:
                f.write(reading_to_string(read_time, reading))

"""Parse a MS reading from the serial connection (or broadly), e.g., no async operations necessary"""
def parse_SERIAL(serial_bytes: bytes) -> tuple:
    # Splice and convert the channels to their respective types 
    AS_channels: np.array = np.frombuffer(serial_bytes[0:20],dtype=np.uint16)
    TS_channels: np.array = np.frombuffer(serial_bytes[20:24],dtype=np.uint16)
    LS_channels = np.array = np.frombuffer(serial_bytes[24:144],dtype=np.int16)
    LS_temp: np.array = np.frombuffer(serial_bytes[144:148],dtype=np.float32)

    return AS_channels, TS_channels, LS_channels, LS_temp 

"""Read packets of data from the MS over Serial Connection"""
def read_SERIAL(write_queue: queue.Queue, stop_flag: threading.Event):
    # Hard Code the port the MS connects to for Linux and MAC
    # its baudrate, and the length of a message in bytes
    com_port: str = '/dev/ttyACM0' if sys.platform.startswith('linux') else '/dev/tty.usbmodem14401'
    baudrate: int = 115200
    msg_length: int = 150

    # Connect to the MS device
    print('Connecting to ms...')
    ms: serial.Serial = serial.Serial(com_port, baudrate, timeout=1)

    # Read until we hit the start delimeter of the MS message 
    while(not stop_flag.is_set()):
        token: bytes = ms.read(1)

        #Check if the token is equal to the starting delimeter
        if(token == b'<'):     
            print(f'Received MS TRANSMISSION @{time.time()}')      
            
            # Read the buffer over the serial port (- 2 for the begin/end delimeters)
            reading_buffer: bytes = ms.read(msg_length - 2)

            # Assert we didn't overread the buffer by reading the next byte and ensuring
            # it's the ending delimeter 
            assert(ms.read(1) == b'>')

            print(f"Size of reading buffer: {len(reading_buffer)}")
            AS, TS, LI, temp = parse_SERIAL(reading_buffer)

            print(f'AS CHANNELS: {AS}')
            print(f'TS CHANNELS: {TS}')
            print(f'LI CHANNELS: {LI}')
            print(f'TEMP: {temp}')

            # Append it to the write queue
            write_queue.put(['NA',  reading_buffer])

            # Flush the reading buffer 
            reading_buffer = None
    
    # Signal the end of the write queue
    write_queue.put(None)
    
    # Close the serial connection
    ms.close()

"""Write data from the MS to the respective data files"""
async def write_MSBLE(write_queue: asyncio.Queue, reading_names: list, output_directory: str):
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

"""Parse the bytes read over bluetooth from the MS"""
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

def sliced(data: bytes, n: int) -> Iterator[bytes]:
    """
    Slices *data* into chunks of size *n*. The last slice may be smaller than
    *n*.
    """
    return takewhile(len, (data[i : i + n] for i in count(0, n)))


"""Read bytes from the MiniSpect over bluetooth via the UART
example from the bleak librray"""
async def read_MSBLE(queue: asyncio.Queue, device_name: str):
    UART_SERVICE_UUID: str = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
    UART_RX_CHAR_UUID: str = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
    UART_TX_CHAR_UUID: str = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

    def match_nus_uuid(device: BLEDevice, adv: AdvertisementData):
        # This assumes that the device includes the UART service UUID in the
        # advertising data. This test may need to be adjusted depending on the
        # actual advertising data supplied by the device.
        if UART_SERVICE_UUID.lower() in adv.service_uuids:
            return True

        return False

    # Find the device by its nam 
    device = await BleakScanner.find_device_by_name(device_name, timeout=30) #.find_device_by_filter(match_nus_uuid,timeout=30) #find_device_by_name("White MS",timeout=30) # find_device_by_filter(match_nus_uuid,timeout=30)

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
            data = data.replace(b"\n", b"\r\n")

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

    id: str = 'White MS'
    read_queue = asyncio.Queue()
    write_queue = asyncio.Queue()

    read_task = asyncio.create_task(read_MSBLE(read_queue, id))
    parse_task = asyncio.create_task(parse_MSBLE(read_queue, write_queue))
    write_task = asyncio.create_task(write_MSBLE(write_queue, reading_names, output_directory))

    #await asyncio.gather(read_task,return_exceptions=True)
    await asyncio.gather(read_task, parse_task, write_task, return_exceptions=True)

if(__name__ == '__main__'):
    asyncio.run(main())