import smbus
import time

# Interval in seconds that readings will be apart
READ_INTERVAL: float = 1.5

"""Record from the device live with no duration"""
def record_live(duration: float, filename: str):
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
def record(duration: float, filename: str):
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
        if(raw_adc > 2047): raw_adc -= 4095
        
        print(f'Sunglasses Writing: {raw_adc}')

        # Write the reading to the reading file
        readings_file.write(f'{raw_adc}\n')

        # Retrieve the current time
        current_time: float = time.time()

        # Check to see if we have reached the desired recording duration
        if(abs(current_time - start_time) >= duration):
            break 
        
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