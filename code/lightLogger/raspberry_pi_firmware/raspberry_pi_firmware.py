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
    parser.add_argument('--shell_output', type=int, choices=[0,1], default=1, help='Enable/Disable output to the terminal from all of the subprocesses')

    args = parser.parse_args()

    return args.config_path, args.n_bursts, args.burst_seconds, bool(args.shell_output)

"""Parse the arguments for each subprocess from the main commandline run file"""
def parse_process_args(config_path: str) -> tuple:
    # Define a container for the experiment name + path 
    experiment_name: str = None

    # Generate a dictionary to store program names and thier arguments
    controllers_and_args: dict = {}
    
    # Open the config file 
    with open(config_path, 'r') as f:
        # Iterate over the lines of the file
        for line_num, line in enumerate(f):
             # Skip commented lines 
            if(len(line.strip()) == 0 or line.strip()[0] == '#'): continue

            # First line is going to be the overarching experiment name + path
            if(experiment_name is None):
                experiment_name = line.strip()
                continue

            # First, split the line into space-based tokens
            tokens: list = line.split(' ')

            # Find the program name
            program_name, *_ = [token for token in tokens 
                                if '.py' in token]

            # Find the file extension for this controller 
            file_extension, *_ = [token for token in tokens 
                                 if 'burstX' in token]
            
            # Define the formula for the filename as the savepath plus the 
            # burst placeholder and extension
            filename_formula: str = os.path.join(experiment_name, os.path.basename(experiment_name.strip('/')) + file_extension)

            # Recombine the args into one commandline string
            args: str = " ".join(tokens[0:1] + [program_name, filename_formula] + tokens[3:]).strip()

            # Because we are going to run this process as a subprocess, 
            # we must ensure it has both the flag and a placeholder 
            # for the pid of this parent process
            assert('--is_subprocess 1' in args and '--parent_pid X' in args)

            # Save the arguments for the given program name
            controllers_and_args[program_name] = args

    return controllers_and_args, experiment_name
     
"""Capture a burst of length burst_seconds
   from all of the sensors"""
def capture_burst(component_controllers: list, CPU_priorities: list, 
                  burst_seconds: float,
                  burst_num: int,
                  shell_output: bool= True) -> None:

    # Determine the current pid of this master process
    master_pid: int = os.getpid()

    # List to keep track of process objects
    processes: list = []

    # Create a mapping by PID to controller name
    controllers_by_pid: dict = {}

    # Initialize a dict of controller names and if they are initialized 
    # or not
    controllers_ready: list = []

    """Define a function to receive signals when the processes are ready"""
    def handle_readysig(signum, frame=None):
        print(f'Received a sensor ready signal!')
        controllers_ready.append(True)

    signal.signal(signal.SIGUSR1, handle_readysig)

    # Iterate over the other scripts and start them with their associated arguments
    for (script, args), (core, priority) in zip(component_controllers.items(), CPU_priorities):
        # In the args, we must replace the burstX with the burst number
        # and the parent process ID with the parent processID of this file 
        args: str = args.replace('burstX', f'burst{burst_num}').replace('--parent_pid X', f'--parent_pid {master_pid}')

        # Launch the subprocess
        p = subprocess.Popen(args,
                             stdout=sys.stdout,
                             stderr=sys.stderr,
                             shell=shell_output)
        
        # For some reason, spawning these sub processes actually makes it so 
        # that the real PID is 2 plus the number reported by subprocess 
        # I presume this is because we are spawning 2 threads? But in any case
        # just record that here 
        changed_pid: int = p.pid + 2

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
        # Also do before change and after to ensure both are top priority
        os.system(f"sudo renice -n -20 -p {p.pid}")
        os.system(f"sudo renice -n -20 -p {changed_pid}")

        # Append this process to the list of processes 
        # and its pid to the list of pids
        processes.append(p)

        # Associate this pid with a component controller 
        controllers_by_pid[p.pid] = script

    # Wait for all of the sensors to initialize by waiting for their signals
    while(len(controllers_ready) != len(component_controllers)):
        print(f'Waiting for all controllers to initialize: {len(controllers_ready)}/{len(component_controllers)}')
    
    # Once all sensors are initialized, send a go signal to them
    print(f'Master process {master_pid} sending go signals...')
    for (pid, component_controller) in controllers_by_pid.items():
        # Reconstruct the altered PID (for unknown reasons) once again
        changed_pid: int = pid+2 
        
        # Send the signal to begin recording
        print(f'\tSending GO to: {changed_pid} | {component_controller}')
        os.kill(changed_pid, signal.SIGUSR1)

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
    config_path, n_bursts, burst_seconds, shell_output = parse_args()

    # Parse the controllers and their arguments
    print('Parsing processes and args...')
    component_controllers, experiment_name = parse_process_args(config_path)

    # Assert we have put some controllers into the file 
    assert(len(component_controllers) != 0)

    # Assert we have entered valid process names and args for each 
    assert(all(name in valid_processes for name in component_controllers))

    # Make a supra directory for this experiment 
    # if it does not exist 
    if(not os.path.exists(experiment_name)):
        os.makedirs(experiment_name)

     # Assign max priority to all processes
    cores_and_priorities: list = [(process_num, -20) for process_num in range(len(component_controllers))]

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
    print(f'Executing: {n_bursts} bursts of {burst_seconds} seconds using processes:')
    for name, args in component_controllers.items():
        print(f'\tProgram: {name} | Args: {args}')   

    # Iterate over the number of bursts
    burst_num: int = 0
    while(burst_num < n_bursts):
        print(f'Begin burst: {burst_num+1}')

        # Capture the burst
        capture_burst(component_controllers, cores_and_priorities, burst_seconds, burst_num, shell_output=shell_output)

        print(f'End burst: {burst_num+1}')

        # Increase the burst num we are on 
        burst_num += 1

        # Sleep for a few seconds for things to flush
        time.sleep(5)


if(__name__ == '__main__'):
    main()