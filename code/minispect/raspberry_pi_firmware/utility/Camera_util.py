from picamera2.encoders import H264Encoder
from picamera2 import Picamera2, Preview
import time

def record_video(cam: Picamera2, encoder: H264Encoder, output_path: str):
    # Begin Recording with a preview
    cam.start_preview(Preview.QTGL)
    cam.start_recording(encoder, output_path)
    
    
    # Simulate capturing things
    while(input("Enter: ") != 'n'):
        continue
    
    # Stop recording
    cam.stop_recording()
    cam.stop_preview()
    
    # Close the picam object 
    cam.close()    
    


def initialize_camera():
    # Set up camera, turn off automatic
    # white balance, white point control,
    # turn on exposure control and
    # gain control
    
    # Initialize camera 
    picam2: Picamera2 = Picamera2()
    
    # Select the mode to put the sensor in
    # (ie, mode for high fps/low res, more pixel HDR etc)
    sensor_mode: dict = picam2.sensor_modes[4]					# Other params ignored, so force the mode by setting these
    #config = picam2.create_video_configuration(queue=False, sensor={'output_size': sensor_mode['size'], 'bit_depth': sensor_mode['bit_depth']})
    
    # Set the mode 
    picam2.configure(picam2.create_video_configuration())
    
    # Set runtime camera information, such as auto-gain
    # auto exposure, white point balance, etc
    picam2.set_controls({'AeEnable':True, 'AwbEnable':False}) # Note, AeEnable changes both AEC and AGC 
    
    
    picam2.title_fields = ['ExposureTime','AnalogueGain']
    
    return picam2



def main():
    # Initialize camera with our desired
    # settings
    cam: Picamera2 = initialize_camera()
    
    # Prepare encoder and output filename
    encoder: H264Encoder = H264Encoder(bitrate=10000000)
    output_file: str = 'test.h264'
    
    record_video(cam, encoder, output_file)

if(__name__ == '__main__'):
    main()