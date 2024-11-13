import subprocess
import sys
import time
import argparse
import psutil
import os 
import signal

"""Parse the command line arguments"""
def parse_args() -> tuple:
    parser: argparse.ArgumentParser = argparse.ArgumentParser(description='Main control software for managing each component of the device')

    parser.add_argument('config_path', type=str, help='Where to read the processes and arguments from')
    parser.add_argument('n_bursts', type=float, help='The number of bursts to take')
    parser.add_argument('burst_seconds', type=int, help='The amount of seconds for each capture burst')

    args = parser.parse_args()

    return args.config_path, args.n_bursts, args.burst_seconds

"""Parse the arguments for each subprocess from the main commandline run file"""
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
     
"""Capture a burst of length burst_seconds
   from all of the sensors"""
def capture_burst(component_controllers: list, CPU_priorities: list, 
                  burst_seconds: float,
                  shell_output: bool= True) -> None:

    # List to keep track of process objects
    processes: list = []

    # Iterate over the other scripts and start them with their associated arguments
    for (script, args), (core, priority) in zip(component_controllers.items(), CPU_priorities):
        # Launch the subprocess
        p = subprocess.Popen(args,
                             stdout=sys.stdout,
                             stderr=sys.stderr,
                             shell=shell_output)
        
        # Turn p into a psutil process so we can set core 
        # affinity and niceity
        psutil_process: psutil.Process = psutil.Process(p.pid)

        # Set the cpu affinity (which core this will run on)
        # as well as its niceity (priority)
        psutil_process.cpu_affinity([core])
        
        # Have to include this to define niceity because 
        # using the psutil_process.nice() command requires sudo 
        # privelges, which if I run this script with, says my 
        # libraries don't exist
        os.system(f"sudo renice -n -20 -p {p.pid}")

        # Append this process to the list of processes 
        processes.append(p)

    # Denote the start time of this burst as when all sensors 
    # have begun and their priorities have been set
    start_time: float = time.time()
    current_time: float = start_time

    # Record burst seconds long
    while((current_time - start_time) < burst_seconds):
        time.sleep(1)
        current_time = time.time()
    
    # Close the processes after recording 
    for process in processes:
        process.wait()

    return


def main():
    # Define a set of valid process names to use for data collection
    valid_processes: set = set(['MS_com.py', 'Sunglasses_com.py', 
                                'Camera_com.py', 'Pupil_com.py'])

    # Parse the file containing the processes to run and their args
    config_path, n_bursts, burst_seconds = parse_args()

    # Parse the controllers and their arguments
    print('Parsing processes and args...')
    component_controllers: dict = parse_process_args(config_path)
    cores_and_priorities: list = [(0,-20), (1, -20), (2,-20), (3,-20)]

    # Assert we have entered valid process names and args for each 
    assert(all(name in valid_processes for name in component_controllers))

    # Now, add the burst seconds of capture argument for the controllers we are 
    # using
    for process in component_controllers:
        # Retrieve the commandline string to run this controller
        commandline_input: str = component_controllers[process]

        # Now, add in to capture infinitely. This is because we will 
        # manually cancel it from this process, and there is less 
        # computation in the live capture
        commandline_input = f"{commandline_input} {burst_seconds}"

        # Resave this input 
        component_controllers[process] = commandline_input

    # Print out each sub program along with its arguments
    print(f'Executing: {n_bursts} of {burst_seconds} seconds using processes:')
    for name, args in component_controllers.items():
        print(f'Program: {name} | Args: {args}')   

    # Iterate over the number of bursts
    burst_num: int = 0
    while(burst_num < n_bursts):
        print(f'Begin burst: {burst_num+1}')

        # Capture the burst
        capture_burst(component_controllers, cores_and_priorities, burst_seconds)

        print(f'End burst: {burst_num+1}')

        # Increase the burst num we are on 
        burst_num += 1

        # Sleep for a few seconds for things to flush
        time.sleep(5)


if(__name__ == '__main__'):
    main()