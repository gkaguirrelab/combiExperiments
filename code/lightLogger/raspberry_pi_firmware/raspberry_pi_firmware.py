import subprocess
import time

def main():
    # List of scripts to run and their associated arguments
    component_controllers = {'MS_com.py': [],
                             'Sunglasses_com.py': ['/home/eds/combiExperiments/code/lightLogger/raspberry_pi_firmware/readings/sunglasses.csv', 'INF']}
                             #'Pupil_com.py': ['test.mp4', 'INF', '--save_video', '1']}

    # List to keep track of process objects
    processes = []

    # Iterate over the scripts and start them with their associated arguments
    for script, args in component_controllers.items():
        p = subprocess.Popen(['python3', script] + args,
                              stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE)
        processes.append(p)

    # Retrieve the processes by name
    #minispect_process, pupil_process = processes 
    minispect_process, sunglasses_process = processes 
    #minispect_process, = processes

    time.sleep(30)
    #pupil_process.terminate()
    #pupil_process.wait()
    
    # Wait for the pupil process to complete for a timed recording
    #pupil_process.wait()

    sunglasses_process.terminate()

    # Then close the minispect process
    minispect_process.terminate()
    
    sunglasses_process.wait()
    minispect_process.wait()


if(__name__ == '__main__'):
    main()