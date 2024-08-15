import numpy as np
import matlab.engine
from PyAGC import AGC
import matplotlib.pyplot as plt

def generate_source() -> tuple:
    eng = matlab.engine.start_matlab()

    ts, source, speed_settings = eng.generate_AGC_QC_source(nargout=3)

    ts = np.squeeze(np.array(ts))
    source = np.squeeze(np.array(source))

    return ts, source, speed_settings 

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
    ts, source, speed_setting = generate_source()

    print(f"TS Shape: {ts.shape}")
    print(f"Source Shape: {source.shape}")
    print(f"Speed Setting: {speed_setting}")

    # Iterate over the source, adjusting the 
    # gain and exposure accordingly
    eng = matlab.engine.start_matlab()
    for i in range(source.shape[0]):
        print(f"{i+1}/{source.shape[0]}")

        # Define the signal for this gain and exposure setting
        s = source[i] * exposure * gain

        # Retrieve the adjusted values via both algorithms
        MAT_adjusted_gain, MAT_adjusted_exposure = eng.AGC(matlab.double(s), 
                                                           matlab.double(gain), 
                                                           matlab.double(exposure), 
                                                           matlab.double(speed_setting), 
                                                           nargout=2)
        
        CPP_adjusted_gain, CPP_adjusted_exposure = [ val for key, val 
                                                    in AGC(s, gain, exposure, speed_setting).items()]

        print(f"MATLAB Gain: {MAT_adjusted_gain} | CPP Gain: {CPP_adjusted_gain} | Difference: {abs(MAT_adjusted_gain - CPP_adjusted_gain)}")
        print(f"MATLAB Exposure: {MAT_adjusted_exposure} | CPP Exposure: {CPP_adjusted_exposure} | Difference: {abs(MAT_adjusted_exposure - CPP_adjusted_exposure)}")

        # Append the values from this time stamp to the container
        gain_container.append([MAT_adjusted_gain, CPP_adjusted_gain])
        exposure_container.append([MAT_adjusted_exposure, CPP_adjusted_exposure])
        signal.append(s)

        # Set gain + exposure to the MATLAB generated versions, as those are the target
        gain, exposure = MAT_adjusted_gain, MAT_adjusted_exposure

    # Convert containers to standardized np.arrays
    signal = np.array(signal)
    gain_container = np.array(gain_container)
    exposure_container = np.array(exposure_container)

    # Calculate fit statistics 
    SSE_gain = np.sum()
    SSE_exposure = np.sum()

    # Plot the findings
    fig, axes = plt.subplots(4,1, figsize=(10,8))
    
    axes[0].plot(ts, np.log10(source), label='Source Modulation')
    axes[0].set_ylim(-3.5, 0.5)
    axes[0].set_title('Source Light Intensity')
    axes[0].set_ylabel('Log Intensity')
    axes[0].legend()

    axes[1].plot(ts, exposure_container[:,0], label='MATLAB')
    axes[1].plot(ts, exposure_container[:,1], label='CPP')
    axes[1].set_ylim(-500, 5500)
    axes[1].set_title('Exposure')
    axes[1].set_ylabel('Exposure [μsecs]')
    axes[1].legend()

    axes[2].plot(ts, gain_container[:,0], label='MATLAB')
    axes[2].plot(ts, gain_container[:,1], label='CPP')
    axes[2].set_ylim(-0.5, 12)
    axes[2].set_title('Gain')
    axes[2].set_ylabel('gain [a.u.]')
    axes[2].legend()

    axes[3].plot(ts, signal, label='Signal')
    axes[3].set_ylim(-25, 300)
    axes[3].set_title('Signal')
    axes[3].set_xlabel('time [seconds]')
    axes[3].set_yticks([i for i in range(0,251,50)])
    axes[3].legend()

    plt.subplots_adjust(hspace=0.5)

    plt.show()

"""

    figure

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

"""

if(__name__ == '__main__'):
    main()