from datetime import datetime
from utility.Pi_util import upload_data, has_internet, \
                            DAILY_UPLOAD_TIME, LAST_UPLOAD_DATE

def main():
    current_time:datetime = datetime.now()
    
    # Standard Practice, upload at a given time each day
    if( current_time.time() == DAILY_UPLOAD_TIME and has_internet() is True):
       
        upload_data()
        
        LAST_UPLOAD_DATE = current_time
    
    # If we missed an upload, upload as soon as the user as internet again
    elif((current_time - LAST_UPLOAD_DATE).days >= 1 and has_internet() is True):
        upload_data()      

        LAST_UPLOAD_DATE = current_time                                 



if(__name__ == '__main__'):
    main()