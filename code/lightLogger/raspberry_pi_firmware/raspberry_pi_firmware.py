import subprocess
import sys
import time
import argparse

"""Parse the command line arguments"""
def parse_args() -> tuple:
    parser: argparse.ArgumentParser = argparse.ArgumentParser(description='Main control software for managing each component of the device')

    parser.add_argument('config_path', type=str, help='Where to read the processes and arguments from')

    args = parser.parse_args()

    return args.config_path 

"""Parse the arguments for each subprocess from the main commandline"""
def parse_process_args(config_path: str) -> dict:
    # Generate a dictionary to store program names and thier arguments
    controllers_and_args: dict = {}
    
    # Open the config file 
    with open(config_path, 'r') as f:
        for line in f:
            # Skip commented lines 
            if(line[0] == '#'): continue

            # First, split the line into space-based tokens
            tokens: list = line.split(' ')

            # Find the program name
            program_name, *_ = [token for token in tokens 
                                if '.py' in token]  

            # Save the arguments for the given program name
            controllers_and_args[program_name] = " ".join([token for token in tokens]).strip()

    return controllers_and_args
            

def main():
    # Define a set of valid process names to use for data collection
    valid_processes: set = set(['MS_com.py', 'Sunglasses_com.py', 
                                'Camera_com.py', 'Pupil_com.py'])

    # Parse the file containing the processes to run and their args
    config_path = parse_args()

    # Parse the controllers and their arguments
    print('Parsing processes and args...')
    component_controllers: dict = parse_process_args(config_path)

    # Assert we have entered valid process names and args for each 
    assert(all(name in valid_processes for name in component_controllers))

    # Print out each sub program along with its arguments
    for name, args in component_controllers.items():
        print(f'Program: {name} | Args: {args}')

    # List to keep track of process objects
    processes: list = []
    
    # Iterate over the other scripts and start them with their associated arguments
    print('Starting processes...')
    for script, args in component_controllers.items():
        p = subprocess.Popen(args,
                             stdout=sys.stdout,
                             stderr=sys.stderr,
                             shell=True)
        processes.append(p)

    # Execute the processes 
    print(f'Executing...')
    try:
        while(True):
            time.sleep(1)
    
    # Close all processes on exception 
    except:
        print('Closing processes...')

        for process in processes:
            process.terminate()
            process.wait()


if(__name__ == '__main__'):
    main()