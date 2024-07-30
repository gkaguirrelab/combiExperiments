import paramiko
import argparse

def parseArgs():
    parser = argparse.ArgumentParser(description="Remotely execute commands on another devie over SSH")
    
    parser.add_argument('host', type=str, help="Hostname of the remote device")
    parser.add_argument('port', type=int, default=22, help='Port of the remote device')
    parser.add_argument('username', type=str, help="Username to log into on the remote device")
    parser.add_argument('password', type=str, help='Password for the username provided on the remote device')
    parser.add_argument('command', type=str, help='Command to run remotely')

    args = parser.parse_args()

    return args.host, args.port, args.username, args.password, args.command

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

    except paramiko.SSHException as e:
        print(f"SSH connection failed: {e}")

    # Close the SSH connection regardless of error or not
    finally:
        ssh.close()

def main():
    host, port, username, password, command = parseArgs()
    
    run_ssh_command(host, port, username, password, command)

if(__name__ == '__main__'):
    main() 