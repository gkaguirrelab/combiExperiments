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

    device = await BleakScanner.find_device_by_filter(match_nus_uuid)

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
    output_directory: str = 'readings/MS'
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