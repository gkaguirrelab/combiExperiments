import numpy as np

# Read bytes from the MiniSpect 
# over bluetooth
def read_MSBLE() -> list:
    pass

# Parse the bytes read over bluetooth 
# from the MiniSpect
def parse_MSBLE(bluetooth_bytes:list) -> tuple:
    AS_channels:np.array = np.array([bluetooth_bytes],dtype=np.uint16)
    TS_channels:np.array = np.array([bluetooth_bytes],dtype=np.uint16)
    LI_channels:np.array = np.array([bluetooth_bytes] + [0],dtype=np.float32)   # 0 is here for temp placeholder
    
    # temp will be condensed into a third LI channel
    temp:float = None

    return AS_channels, TS_channels, LI_channels