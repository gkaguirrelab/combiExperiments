import numpy as np
import matlab.engine
from PyAGC import AGC
import matplotlib.pyplot as plt

def generate_source() -> np.array:
    
    return np.array([]) 

# WORK IN PROGRESS

def main():
    # Define initial parameters
    gain = 1
    exposure = 37
    speed_setting = 0.7
    
    # Define containers to hold values as they are read
    signal = []
    gain_container = []
    exposure_container = []

    # Generate the source modulation
    source = generate_source()

    # Iterate over the source, adjusting the 
    # gain and exposure accordingly
    eng = matlab.engine.start_matlab()
    for i in range(source.shape[0]):
        # Define the signal for this gain and exposure setting
        s = source[i] * exposure * gain

        # Retrieve the adjusted values via both algorithms
        MAT_adjusted_gain, MAT_adjusted_exposure = eng.AGC(s, gain, exposure, speed_setting, nargout=2)
        CPP_adjusted_gain, CPP_adjusted_exposure = [ val for key, val in AGC(s, gain, exposure, speed_setting).items()]

        # Append the values from this time stamp to the container
        gain_container.append([MAT_adjusted_gain, CPP_adjusted_gain])
        exposure_container.append([MAT_adjusted_exposure, CPP_adjusted_exposure])
        signal.append(s)

        # Set gain + exposure to the MATLAB generated versions, as those are the target
        gain, exposure = MAT_adjusted_gain, MAT_adjusted_exposure

    signal = np.array(signal)
    gain_container = np.array(gain_container)
    exposure_container = np.array(exposure_container)

    fig, axes = plt.subplots(4,1)
    
    axes[0].plt(ts, np.log10(source), label='Source Modulation')



subplot(4,1,1)
plot(ts,log10(source),'-r','LineWidth',1.5);
hold on
ylim([-3.5 0.5]);
title('source light intensity')
ylabel('log intensity')
subplot(4,1,2)
plot(ts,exposureStore,'-r','LineWidth',1.5);
ylim([-500 5500]);
hold on
title('exposure')
ylabel('exposure [μsecs]')
subplot(4,1,3)
plot(ts,gainStore,'-r','LineWidth',1.5);
ylim([-0.5 12]);
hold on
title('gain')
ylabel('gain [a.u.]')
subplot(4,1,4)
plot(ts,signal,'-r','LineWidth',1.5);
hold on
ylim([-25 300])
title('signal')
xlabel('time [seconds]')
a = gca();
a.YTick = [0:50:250];


if(__name__ == '__main__'):
    main()