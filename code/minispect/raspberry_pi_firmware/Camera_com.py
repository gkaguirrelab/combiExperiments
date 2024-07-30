from utility.Camera_util import record_video
import argparse

def parseArgs():
    parser = argparse.ArgumentParser(description='Record videos from the camera via the RP')
    parser.add_argument('output_path', type=str, help='Path to output the recorded video to')
    parser.add_argument('duration', type=float, help='Duration of the video')

    args = parser.parse_args()
    
    return args.output_path, args.duration

def main():
    output_path, duration = parseArgs()

    record_video(output_path, duration)



if(__name__ == '__main__'):
    main()