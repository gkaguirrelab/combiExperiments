import numpy as np
import matlab.engine
from PyAGC import AGC

def generate_source() -> np.array:
    
    return np.array([]) 

# WORK IN PROGRESS

def main():
    gain = 1
    exposure = 37
    signal = []
    gain_container = []
    exposure_container = []

    source = generate_source()

    eng = matlab.engine.start_matlab()
    for i in range(source.shape[0]):
        MAT_adjusted_gain, MAT_adjusted_exposure = eng.AGC(s, gain, exposure, speedSetting, nargout=2)
        cpp_ret_dict = AGC()

        gain, exposure = MAT_adjusted_gain, MAT_adjusted_exposure


if(__name__ == '__main__'):
    main()