import smbus
import time
import threading
import os
import signal

# Interval in seconds that readings will be apart
READ_INTERVAL: float = 5

"""Record from the device live with no duration"""
def record_live(duration: float, filename: str,
                is_subprocess: bool, parent_pid: int,
                go_flag: threading.Event):
    # Initialize the readings file variable
    readings_file: object = None

    # Record live
    try:
        # Initialize a connection to the device
        device: smbus.SMBus = initialize_connection()

        # Initialize the file to output readings to
        readings_file: object = open(filename, 'a')

        # Begin recording
        last_read: float = time.time()
        while(True):
            # Capture the current time
            current_time: float = time.time()
            
            # If not at a read time, skip 
            if((current_time - last_read)) < READ_INTERVAL:
                continue

            # Read data from the device
            data = device.read_i2c_block_data(0x6b, 0x00, 2)

            # Convert the data read to 12 bits
            raw_adc = (data[0] & 0x0F) * 256 + data[1]
            if(raw_adc > 2047) : raw_adc -= 4095
            
            print(f'Sunglasses Writing: {raw_adc}')

            # Write the reading to the reading file
            readings_file.write(f'{raw_adc}\n')

            # Update the last read time 
            last_read = current_time
    
    # When exception is raised, close the file
    except KeyboardInterrupt:
        readings_file.close()

"""Record from the device for a given duration"""
def record(duration: float, filename: str,
           is_subprocess: bool, parent_pid: int, 
           go_flag: threading.Event):
    # Initialize a connection to the device
    device: smbus.SMBus = initialize_connection()

    # Initialize the file to output readings to
    readings_file: object = open(filename, 'a')

    # If we were run as a subprocess, send a message to the parent 
    # process that we are ready to go
    if(is_subprocess): 
        print('Sunglasses: Initialized. Sending ready signal...')
        os.kill(parent_pid, signal.SIGUSR1)

        # While we have not receieved the GO signal wait 
        last_read: float = time.time()
        while(not go_flag.is_set()):
            # Every 2 seconds, output a message
            current_wait: float = time.time()
            
            if((current_wait - last_read) >= 2):
                print('Sunglasses: Waiting for GO signal...')
                last_read = current_wait

    # Once the go signal has been received, begin capturing
    print('Sunglasses: Beginning capture')

    # Begin recording
    start_time: float = time.time()
    last_read: float = time.time()
    while(True):
        # Capture the current time
        current_time: float = time.time()

        # Check to see if we have reached the desired recording duration
        if(abs(current_time - start_time) >= duration):
            break 
        
        # If not at a read time, skip 
        if((current_time - last_read)) < READ_INTERVAL:
            continue

        # Read data from the device
        data = device.read_i2c_block_data(0x6b, 0x00, 2)

        # Convert the data read to 12 bits
        raw_adc = (data[0] & 0x0F) * 256 + data[1]
        if(raw_adc > 2047): raw_adc -= 4095
        
        print(f'Sunglasses Writing: {raw_adc}')

        # Write the reading to the reading file
        readings_file.write(f'{raw_adc}\n')

        # Update the last read time
        last_read = current_time    
    
    # Close the readings file
    readings_file.close()


"""Initialize a connection to the sunglasses detector"""
def initialize_connection() -> smbus.SMBus:
    # Get I2C bus
    bus: smbus.SMBus = smbus.SMBus(1)

    # MCP3426 address, 0x68(104)
    # Send configuration command
    #		0x10(16)	Continuous conversion mode, 12-bit Resolution
    bus.write_byte(0x6b, 0x10)

    return bus