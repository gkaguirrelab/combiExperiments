import pickle 
import argparse
import numpy as np
import os

"""Parse arguments from the command line"""
def parse_args() -> tuple:
    parser = argparse.ArgumentParser(description="Test the Python wrapper for the CPP AGC")

    parser.add_argument("signal", type=float)
    parser.add_argument("gain", type=float)
    parser.add_argument("exposure", type=float)
    parser.add_argument("speed_settings", type=float)

    args = parser.parse_args()

    return args.signal, args.gain, args.exposure, args.speed_settings

"""Calculate the adjusted gain and exposure for a current state"""
def AGC(signal: float, gain: float, exposure: float, speed_setting: float) -> dict:
    import ctypes

    # Define the same structure as that returned by the CPP AGC
    class RetVal(ctypes.Structure):
        _fields_ = [("adjusted_gain", ctypes.c_double),
                    ("adjusted_exposure", ctypes.c_double)]

    # Find the compiled shared cpp library 
    cwd, filename = os.path.split(os.path.abspath(__file__))
    AGC_cpp_path = os.path.join(cwd, 'AGC.so')
    
    # Read in the cpp AGC library and define its
    # arguments' types and return type 
    agc_lib = ctypes.CDLL(AGC_cpp_path) 
    agc_lib.AGC.argtypes = [ctypes.c_double]*4
    agc_lib.AGC.restype = RetVal

    # Call the cpp AGC 
    ret_val = agc_lib.AGC(signal, gain, exposure, speed_setting)

    return {"adjusted_gain": ret_val.adjusted_gain,
            "adjusted_exposure": ret_val.adjusted_exposure}


def main():
    signal, gain, exposure, speed_settings = parse_args()

    print(f"signal {signal}, gain {gain}, exposure: {exposure}, {speed_settings}")

    ret_val = AGC(signal, gain, exposure, speed_settings)

    print(ret_val)


if(__name__ == '__main__'):
    main()

