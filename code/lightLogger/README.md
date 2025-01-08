# GKA Lab | High-Speed Personal Light Logger
*Authors: Zachary Kelly, Geoffrey Aguirre, Vincent Lau*

## Introduction 

TODO

## Notes
Vincent + Geoff, if you are going to attempt to work on this, I **highly** recommend ssh-ing into the Raspberry Pi when working with any of its firmware rather than trying to build all this software on your local machine. I do not have a complete guide yet for doing so, and by nature of the project undergoing lots of changes now, it would not be consistently up to date. When analyzing recordings, you are welcome to do so on your local machines or connect to the Raspberry Pi, though I cannot guarantee Jupyter Notebook being conveniently accessible at the moment on it.  

You can ssh into the Raspberry Pi when connected to AirPennNet (either locally or through VPN) by doing the following: 
```
$ ssh rpiControl@10.102.141.235
$ rpiControl@10.102.141.235's password: DEFAULT PASSWORD (a certain sequence of numbers)
```

## Current State

The project state is currently such that recordings can be made and saved from all sensors at their target FPS, either individually or simultanously, via code written and C++. Recordings are made continuously for a given duration (up to ```2^32-1``` seconds) and buffers of ```10``` seconds are written to disk in parallel to active capture. This uses a double buffer stragegy, writing one buffer while recording and fill another, switching between them when each recorder has captured enough frames for that buffer. This also includes using the automatic gain control *(AGC)* that we wrote ourselves to adjust world camera settings on the fly. However, it does **not** include downsampling of the world camera. This functionality has been completed individually, located in downsampled.cpp, but has not yet been included in ```rpi_cpp.cpp``` (name to change in the future, too). Therefore, the data written to disk for the world camera is entirely dummy data.

Recordings can also be analyzed using the ```parse_chunks_binary``` function located in ```Pi_util.py```. This will parse the serialized data for each chunk, as well as the ```.csv``` file denoting the duration of the recording and how many frames were captured in total by all the sensors. You can then analyze sensor data in ```10``` second intervals *or* flatten this array for a given sensor and analyze performance for the entire recording. 

## Future Work and Outstanding Questions

There is still much to do on the project, much of it pertaining to the switch over to C++. Some major things include:

1. Determine why the data written appears to be junk for all sensors. For instance, the MS seems to write entirely ```0``` for the light-sensing chips, and random data for the accelerometer. The latter is somewhat expected, but I have yet to confirm that this is the *right* standard values output (the baseline numbers for the sensor). The sunglasses, too, behave strangely. Firstly, the chunks do not appear to be uniform in shape after converting to 16 bit values during video analysis. Additionally, these numbers definintely differ wildly from what I expect the baseline outputs to be (~1600 ish). 
2. Figure out how to properly save and load pupil camera frames. Theoretically, this is already done, but ```libUVC``` does **not** allow me to simply grab the frames in any other format than ```MPEG```, which is a compressed format. The bytes allocated in the buffer I have created are for ```(400,400)``` images. The bytes produced by the library tend to align with ```(40x40)``` but have some variation (for instance ```1548, 1575``` bytes). This means the method that I am using to uniformly read them does not work because the number of bytes are not consistent, though all of the framework for this is there. 
3. Implement the already-written downsampling code to downsample the world camera's data, when it is no longer junk. Right now, the world camera data is not being saved other than the first frame to prevent segmentation faults. This is because the buffer I have passed is for the size it is to be written at. I will have to make another buffer to hold the frames as they are acquired, then downsample them to this buffer, then write to disk. 
4. Switch buffers over to using ```std::list``` instead of ```std::vector```. This is a simplier class, has more stringent bounds-checking, and is really all that I need. I don't particularly need vector for my operations. 
5. Finish the Python parsing code for the chunks, in particular, fixing how it handles the pupil images  and sunglasses data (while fixing the problems above), as well as implementing the world parser. 
6. Resume making recordings to calculate fits and phase offsets. This will also entail a large change to existing code since the architecture has changed so much. 

## Device Usage 

On a Raspberry Pi power-pack, all sensors should be connected and the device should be powered on. Then, navigate to the ```raspberry_pi_firmware``` directory. 
```
$ cd ~/combiExperiments/code/lightLogger/raspberry_pi_firmware
```

As I am currently working on this, all code should already be made and just require makes when you update things. Use the makefile in this directory to remake the code 
```
$ pwd
$ /home/rpiControl/combiExperiments/code/lightLogger/raspberry_pi_firmware
$ make 
```

The executable for the Raspberry Pi firmware is called ```FIRMWARE```. You can run it by doing the following: 
```
$ ./FIRMWARE -s 1 -p 1 -w 1 -m 1 -d 30 -o /media/rpiControl/FF5E-7541/allSensorsCPP
```

All of the flags correspond to the sensors that you want to be active, except for ```-d``` and ```-o``` which are the duration (in seconds) and the output path respectively. The output path does not have to exist. 

The code for ```FIRMWARE``` lives in ```rpi_cpp.cpp```. 
 
## Recording Analysis
Analysis of recordings at this stage boils down to parsing the recorded binary files into Python and then handling them however you want. What I recommend is utilizing Jupyter Notebook to do this, particularly the one located in the ```raspberry_pi_firmware``` directory. Your workflow will look something like the following 


``` python
# CODE BLOCK 1 -- IMPORTS 
import numpy as np
import utility.Pi_util
import importlib
import pandas as pd
import matplotlib.pyplot as plt
# Here are some example libraries. 
# This is not an exhaustative list, 
# but rather just some of what I use frequently. 

# CODE BLOCK 2 -- Parse a recording into Python 
# Importlib will usually save you from having to restart the kernel, 
# but not always 
importlib.reload(utility.Pi_util) 
recording_path: str = '/Volumes/EXTERNAL1/allSensorsCPP/'
results: dict = utility.Pi_util.parse_chunks_binary(path)

# CODE BLOCK 3 -- Manipulate the data as you wish 

# For instance, retrieve the info df and sensor results from 
# all of the chunks 
performance_df: pd.DataFrame = results['performance_df']
chunks: list = results['chunks']

# Iterate over the chunks 
for chunk in chunks:

    # Retrieve the difference sensors' data 
    ms_data: tuple = chunk['M'] 
    world_data: np.ndarray = chunk['W']
    pupil_data: list = chunk['P']
    sunglasses_data: np.ndarray = chunk['S']

    # Do things with the data... 

```

## Installation

*WIP for when project is further along*

First, clone the repository by running the following
```$ git clone https://github.com/gkaguirrelab/combiExperiments ```

Navigate to the ```lightLogger``` subdirectory. This is where all of the code for the light logger lives. 
```$ cd combiExperiments/code/lightLogger ```

Here, you will find several more subdirectories. We will now need to build the C++ code for the device. 
```
$ cd raspberry_pi_firmware 
$ make
```
