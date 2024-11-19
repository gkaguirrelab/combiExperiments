import os 
import re
from natsort import natsorted


"""Group chunks' information together from a recording file and return them 
   as a list of tuples"""
def parse_chunk_paths(experiment_path: str) -> list:
    # Define a container for the sorted chunks 
    sorted_chunks: list = []

    # Find all of the names in the experiment path 
    experiment_files: list = os.listdir(experiment_path)

    # Find all of the bursts in sorted order
    burst_names: list = natsorted(set([re.search(r'burst\d+', file).group() 
                        for file in experiment_files]))

    # Iterate over the burst names and build the filepaths
    # all of a given burst's readings
    for burst_idx, burst_name in enumerate(burst_names):
        # Construct filepaths to all of the readings for a given bursts 
        # by iterating over the files in the directory and finding 
        # those that contain the burst name. Sort so it is always in
        # the same order
        burst_readings: list = sorted((os.path.join(experiment_path, file)
                                       for file in experiment_files
                                       if burst_name in file))

        # Append this chunks' readings to the growing list
        sorted_chunks.append(burst_readings)

    return sorted_chunks

def main():
    pass 

if(__name__ == '__main__'):
    pass