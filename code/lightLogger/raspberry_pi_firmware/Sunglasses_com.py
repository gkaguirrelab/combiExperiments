import argparse
import os
import sys

"""Import utility functions from the device recorder"""
recorder_lib_path = os.path.join(os.path.dirname(__file__), '..', 'sunglasses')
sys.path.append(os.path.abspath(recorder_lib_path))
from recorder import record_live, record

"""Parse arguments via the command line"""
def parse_args() -> tuple:
    parser = argparse.ArgumentParser(description='Record videos from the camera via the RP')
    
    parser.add_argument('output_path', type=str, help='Path to the readings file') 
    parser.add_argument('duration', type=float, help='Duration of the recording')
   
    args = parser.parse_args()
    
    return args.output_path, args.duration

def main():
    # Parse the command line arguments
    output_path, duration = parse_args()
        
    # Select whether to use the set-duration video recorder or the live recorder
    recorder: object = record_live if duration == float('INF') else record 

    # Try capturing
    try:
        recorder(duration, output_path)
    
    # If the capture was canceled via Ctrl + C
    except KeyboardInterrupt:
        pass 

    # Close capture regardless of interrupt or not
    finally:
        pass






if(__name__ == '__main__'):
    main()