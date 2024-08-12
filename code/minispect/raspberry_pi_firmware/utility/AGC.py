import pickle 
import argparse

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

        
    agc_lib = ctypes.CDLL('./AGC.so') 
    agc_lib.AGC.argtypes = [ctypes.c_double]*4
    agc_lib.AGC.restype = RetVal

    ret_val = agc_lib.AGC(signal, gain, exposure, speed_setting)

    return {"adjusted_gain": ret_val.adjusted_gain,
            "adjusted_exposure": ret_val.adjusted_exposure}

def main():
    signal, gain, exposure, speed_settings = parse_args()

    print(f"signal {signal}, gain {gain}, exposure: {exposure}, {speed_settings}")

    ret_val = AGC(signal, gain, exposure, speed_settings)

    print(ret_val)

    #print(ret_val)


if(__name__ == '__main__'):
    main()