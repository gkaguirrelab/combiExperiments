from datetime import datetime,time
import requests

DAILY_UPLOAD_TIME = time(0,0,0)
LAST_UPLOAD_DATE = None

# Upload the data from the raspberry 
# pi to our servers
def upload_data():
    pass

# Detect if the raspberry pi is 
# currently connected to wifi
def has_internet():
    # Try connecting to a well-maintained website
    try: 
        # If the line executes, we have internet
        response = requests.get("http://www.google.com", timeout=10)

        return True

    # If there was a connection error, we do 
    # not have internet
    except requests.ConnectionError:
        
        return False


def main():
    pass 

if(__name__ == '__main__'):
    pass