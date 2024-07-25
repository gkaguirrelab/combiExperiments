from picamera2 import Picamera2

def main():
    picam2: Picamera2 = Picamera2()
    print(picam2.camera_controls.items())

    picam2.close()



if(__name__ == '__main__'):
    main()