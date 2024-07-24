from picamera2 import Picamera2

def main():
    picam2 = Picamera2()
    picam2.start_and_record_video("Desktop/new_video.mp4", duration=5, show_preview=True)
    picam2.close()



if(__name__ == '__main__'):
    main()