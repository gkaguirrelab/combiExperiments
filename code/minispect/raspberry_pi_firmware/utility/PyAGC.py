import pickle 
import argparse
#import matlab.engine
import numpy as np

def parse_args():
    parser = argparse.ArgumentParser(description="Test the Python wrapper for the CPP AGC")

    parser.add_argument("signal", type=float)
    parser.add_argument("gain", type=float)
    parser.add_argument("exposure", type=float)
    parser.add_argument("speed_settings", type=float)

    args = parser.parse_args()

    return args.signal, args.gain, args.exposure, args.speed_settings


def AGC(signal: float, gain: float, exposure: float, speed_setting: float):
    import ctypes

    class RetVal(ctypes.Structure):
        _fields_ = [("adjusted_gain", ctypes.c_double),
                    ("adjusted_exposure", ctypes.c_double)]

        
    agc_lib = ctypes.CDLL('./utility/AGC.so') 
    agc_lib.AGC.argtypes = [ctypes.c_double]*4
    agc_lib.AGC.restype = RetVal

    ret_val = agc_lib.AGC(signal, gain, exposure, speed_setting)

    return {"adjusted_gain": ret_val.adjusted_gain,
            "adjusted_exposure": ret_val.adjusted_exposure}
"""
def QC_AGC():
    # Test 1: If we need to decrease settings but gain is pegged
    test1 = [123, 1.0, 3925.43, 0.99]
    # Test 2: If we need to decrease settings but exposure is pegged
    test2 = [123, 8.3, 4839.00, 0.99]
    # Test 3: If we need to increase settings but gain is floored
    test3 = [70, 10.667, 4839.00, 0.99]
    # Test 4: If we need to increase settings but exposure is floored
    test4 = [50, 5, 37, 0.99]

    # Initialize the MATLAB engine
    eng = matlab.engine.start_matlab()

    for test in (test1, test2, test3):
        signal, gain, exposure, speed_setting = test

        print(f"signal {signal}, gain {gain}, exposure: {exposure}, {speed_setting}")
        
        MATLAB_gain, MATLAB_exposure = eng.AGC(matlab.double(signal), 
                                               matlab.double(gain), 
                                               matlab.double(exposure), 
                                               matlab.double(speed_setting), 
                                               nargout=2)
        cpp_retval = AGC(signal, gain, exposure, speed_setting)

        #MATLAB_gain, MATLAB_exposure = matlab_retval['adjusted_gain'], matlab_retval['adjusted_exposure']
        cpp_gain, cpp_exposure = cpp_retval['adjusted_gain'], cpp_retval['adjusted_exposure']

        gain_difference = abs(MATLAB_gain - cpp_gain)
        exposure_difference = abs(MATLAB_exposure - cpp_exposure)

        print(f"MATLAB Gain: {MATLAB_gain} | CPP Gain: {cpp_gain} | Difference: {gain_difference}")
        print(f"MATLAB Exposure: {MATLAB_exposure} | CPP Exposure: {cpp_exposure} | Difference: {exposure_difference}")
"""


def main():
    #signal, gain, exposure, speed_settings = parse_args()

    #print(f"signal {signal}, gain {gain}, exposure: {exposure}, {speed_settings}")

   #ret_val = AGC(signal, gain, exposure, speed_settings)

    QC_AGC()

    #print(ret_val)

    #print(ret_val)


if(__name__ == '__main__'):
    main()

