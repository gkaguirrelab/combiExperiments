import paramiko
import argparse

"""Parse args if run as main program"""
def parseArgs():
    parser = argparse.ArgumentParser(description="Remotely execute commands on another devie over SSH")
    
    parser.add_argument('host', type=str, help="Hostname of the remote device")
    parser.add_argument('port', type=int, default=22, help='Port of the remote device')
    parser.add_argument('username', type=str, help="Username to log into on the remote device")
    parser.add_argument('password', type=str, help='Password for the username provided on the remote device')
    parser.add_argument('command', type=str, help='Command to run remotely')

    args = parser.parse_args()

    return args.host, args.port, args.username, args.password, args.command

"""Execute a command over remote SSH to a desired connection"""
def run_ssh_command(hostname: str, port: int, username: str, password: str, command: str):
    # Create an SSH client instance
    ssh = paramiko.SSHClient()

    # Automatically add the server's host key (disable for stricter security)
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    try:
        # Connect to the remote server
        ssh.connect(hostname, port=port, username=username, password=password)

        # Execute the command
        stdin, stdout, stderr = ssh.exec_command(command)

        # Read the output of the program, used to stall any 
        # external programming calling this program to wait 
        # for it to finish
        
        stdout_output = stdout.read().decode('utf-8') 
        stderr_output = stderr.read().decode('utf-8') 

        print(stdout_output, flush=True)
        print(stderr_output, flush=True)


    except paramiko.SSHException as e:
        print(f"SSH connection failed: {e}")

    # Close the SSH connection regardless of error or not
    finally:
        ssh.close()

def main():
    host: str = '10.102.141.235'
    username: str = 'rpiControl' 
    port: int = 22
    password: str = '1234'
    virtual_environment_init = 'source /home/rpiControl/.python_environment/bin/activate'
    command: str = f'{virtual_environment_init} && python3 /home/rpiControl/combiExperiments/code/lightLogger/raspberry_pi_firmware/Camera_com.py test.avi 10 --save_frames 0'
    
    run_ssh_command(host, port, username, password, command)

if(__name__ == '__main__'):
    main() 