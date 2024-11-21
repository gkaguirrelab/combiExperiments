import subprocess
import sys
import time
import argparse
import psutil
import os 
import signal
import traceback

# Define the time in seconds to wait before 
# raising a timeout error
sensor_initialization_timeout: float = 45

# The time in seconds to allow for sensors to start up
sensor_initialization_time: float = 1.5

"""Parse the command line arguments"""
def parse_args() -> tuple:
    parser: argparse.ArgumentParser = argparse.ArgumentParser(description='Main control software for managing each component of the device')

    parser.add_argument('config_path', type=str, help='Where to read the processes and arguments from')
    parser.add_argument('n_bursts', type=float, help='The number of bursts to take')
    parser.add_argument('burst_seconds', type=int, help='The amount of seconds for each capture burst')
    parser.add_argument('--shell_output', type=int, choices=[0,1], default=1, help='Enable/Disable output to the terminal from all of the subprocesses')

    args = parser.parse_args()

    return args.config_path, args.n_bursts, args.burst_seconds, bool(args.shell_output)

"""Find all PIDS of processes with a given name"""
def find_all_pids(target_name: str) -> list:
    # Initialize a list to store the pids we find 
    # of processes with the target name
    pids: list = []

    # Iterate over the existing processes
    for proc in psutil.process_iter(attrs=['pid', 'name']):
        # Try to access the process information
        try:
            # Get the process's info, including name and pid
            process_name: str = proc.info['name']
            pid: int = proc.info['pid']
            
            # Check if process name matches the target name
            if(process_name == target_name):
                pids.append(pid)
        
        # Skip errored processes
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            pass
    
    return pids

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
   from all of the sensors by recalling 
   the controllers repeatedly (and thus 
   reinitializing all of the sensors over and over)"""
def capture_burst_multi_init(info_file: object, component_controllers: list, CPU_priorities: list, 
                             burst_seconds: float, burst_num: int, shell_output: bool= True) -> None:

    # Determine the current pid of this master process
    master_pid: int = os.getpid()

    # List to keep track of process objects
    processes: list = []

    # Initialize a dict of controller names and if they are initialized 
    # or not
    controllers_ready: list = []

    """Define a function to receive signals when the processes are ready"""
    def handle_readysig(signum, frame, siginfo=None):
        print(f'Received a sensor ready signal!')
        
        # Determine the pid of the sender
        sender_pid: int = siginfo.si_pid 

        # Record the time the signal was received 
        time_received: float = time.time()
        
        # Append the ready signal and the time received to controllers ready
        controllers_ready.append((True, time_received))
    
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

        # Append this process to the list of processes 
        # and its pid to the list of pids
        processes.append(p)

    # Wait for all of the sensors to initialize by waiting for their signals
    try:
        start_wait: float = time.time()
        last_read: float = time.time()
        while(len(controllers_ready) != len(component_controllers)):
            # Capture the current time
            current_wait: float = time.time()

            # If we waited N seconds without all sensors being ready, throw an error
            if((current_wait - start_wait) >= sensor_initialization_timeout):
                raise Exception('ERROR: Main controller did not receive enough READY signals by timeout')
            
            # Every 2 seconds, output a messag
            if((current_wait - last_read) >= 2):
                print(f'Waiting for all controllers to initialize: {len(controllers_ready)}/{len(component_controllers)}')
                last_read = current_wait
    
    # Catch and safely handle when the sensors error in their initialization
    except Exception as e:
        # Print the traceback of the function calls that caused the error
        traceback.print_exc()
        print(e)
        print('Main process did not receive sensors ready signal in time. Exiting...')
        sys.exit(1)
    
    # Have all sensors sleep for N seconds 
    time.sleep(sensor_initialization_time)
    
    # Find the current PID of all of the controllers (basically, everything with Python in it)
    pids: list = find_all_pids('python3')

    # Once all sensors are initialized, send a go signal to them
    print(f'Master process {master_pid} sending go signals...')

    # Record the time the go signal was sent by the master process
    time_sent: float = time.time()
    for pid in pids:        
        # Send the signal to begin recording
        print(f'\tSending GO to: {pid}')
        os.kill(pid, signal.SIGUSR1)

    # Denote the start time of this burst as when all sensors 
    # have begun and their priorities have been set
    start_time: float = time.time()
    current_time: float = start_time

    # Record burst seconds long with extra time for initialization 
    while((current_time - start_time) < burst_seconds):
        time.sleep(1)
        current_time = time.time()
    
    # Close the processes after recording 
    for process in processes:
        process.wait()

    # Record the time the processes ready signals 
    # were received as well as the go time sent
    chunk_signal_info: str = ",".join([str(time) for (state, time) in controllers_ready] + [str(time_sent)])
    info_file.write(chunk_signal_info + "\n")

    return


"""Capture a burst of length burst_seconds
   from all of the sensors by calling the controllers 
   once and communicating with signals when to start/stop
   the next chunk"""
def capture_burst_single_init(info_file: object, component_controllers: list, CPU_priorities: list, 
                              burst_seconds: float, n_bursts: int, shell_output: bool= True) -> None:

    # Determine the current pid of this master process
    master_pid: int = os.getpid()

    # List to keep track of process objects
    processes: list = []

    # Initialize a dict of controller names and if they are initialized 
    # or not
    controllers_ready: list = []

    """Define a function to receive signals when the processes are ready"""
    def handle_readysig(signum, frame, siginfo=None):
        print(f'Master process: Received a sensor ready signal!')
        
        # Record the time the signal was received 
        time_received: float = time.time()
        
        # Append the ready signal and the time received to controllers ready
        controllers_ready.append((True, time_received))
    
    signal.signal(signal.SIGUSR1, handle_readysig)

    # Iterate over the other scripts and start them with their associated arguments
    for (script, args), (core, priority) in zip(component_controllers.items(), CPU_priorities):
        # In the args, we must replace the burstX with the burst number
        # and the parent process ID with the parent processID of this file 
        args: str = args.replace('--parent_pid X', f'--parent_pid {master_pid}')

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
        # Also do before change and after to ensure both are top priority
        os.system(f"sudo renice -n -20 -p {p.pid}")

        # Append this process to the list of processes 
        # and its pid to the list of pids
        processes.append(p)

    # Wait for all of the sensors to initialize by waiting for their signals
    try:
        start_wait: float = time.time()
        last_read: float = time.time()
        while(len(controllers_ready) != len(component_controllers)):
            # Capture the current time
            current_wait: float = time.time()

            # If we waited N seconds without all sensors being ready, throw an error
            if((current_wait - start_wait) >= sensor_initialization_timeout):
                raise Exception('ERROR: Master process did not receive enough READY signals by timeout')
            
            # Every 2 seconds, output a messag
            if((current_wait - last_read) >= 2):
                print(f'Waiting for all controllers to initialize: {len(controllers_ready)}/{len(component_controllers)}')
                last_read = current_wait
    
    # Catch and safely handle when the sensors error in their initialization
    except Exception as e:
        # Print the traceback of the function calls that caused the error
        traceback.print_exc()
        print(e)
        print('Master Process: Did not receive sensors ready signal in time. Exiting...')
        sys.exit(1)

    # Have all sensors sleep for N seconds 
    time.sleep(sensor_initialization_time)
    
    # Find the current PID of all of the controllers (basically, everything with Python in it)
    pids: list = find_all_pids('python3') 
    pids.remove(master_pid) # remove the master pid so there isn't a duplicate

    # Define the burst we are on
    burst_num: int = 0 
    
    # Capture the desired amount of bursts
    while(burst_num < n_bursts):
        # Clear the history of ready sensors
        controllers_ready.clear()

        # Note which burst we are on 
        print(f'Master process: Burst num: {burst_num+1}/{n_bursts}')

        # Once all sensors are initialized, send a go signal to them
        print(f'Master process: {master_pid} sending GO signals...')

        # Capture when the GO signal is sent to the controllers
        #time_sent: float = time.time()
        for pid in pids:        
            # Send the signal to begin/continue recording
            print(f'\tMaster Process | Sending GO to: {pid}')
            os.kill(pid, signal.SIGUSR1)
        
        # Wait until we have received all of the sensors have finished 
        # this chunk before saying go to the next one
        last_read: float = time.time()
        current_wait: float = last_read 
    
        # Wait for the subcontrollers to be ready for the next chunk
        while(len(controllers_ready) != len(component_controllers)):
            if((current_wait - last_read) >= 2):
                print(f'Master Process: Waiting for sensors to be ready... {len(controllers_ready)}/{len(component_controllers)}')
                
            time.sleep(0.5)
        
        # Increment the burst number 
        burst_num += 1
    
    
    # If we have recorded the desired bursts, 
    # send a stop signal 
    for pid in pids:        
        # Send the signal to STOP recording
        print(f'\tSending STOP to: {pid}')
        os.kill(pid, signal.SIGUSR2)
    
    # Close the processes after recording 
    for process in processes:
        process.wait()

    # Record the time the processes ready signals 
    # were received as well as the go time sent
    #chunk_signal_info: str = ",".join([str(time) for (state, time) in controllers_ready] + [str(time_sent)])
    #info_file.write(chunk_signal_info + "\n")

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

    # Initialize a .csv to track when sensors report ready 
    # and when go signals are sent 
    experiment_info_file: str = open(os.path.join(experiment_name, 'info_file.csv'), 'a')
    experiment_info_file.write('READY0,READY1,READY2,READY3,GO\n')

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
    capture_burst_single_init(experiment_info_file, component_controllers, cores_and_priorities,
                              burst_seconds, n_bursts, shell_output=True)
    
    # Close the info file
    experiment_info_file.close()


if(__name__ == '__main__'):
    main()