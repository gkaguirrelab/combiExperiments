import subprocess

def main():
    # List of scripts to run
    component_controllers = {'MS_com.py': [], 
                             'Pupil_com.py': ['test.mp4', '10']}

    # List to keep track of process objects
    processes = []

    for script, args in component_controllers.items():
        # Start each script as a subprocess
        p = subprocess.Popen(['python3', script] + args,
                              stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE)
        processes.append(p)

    



if(__name__ == '__main__'):
    main()