clear
close all

% "Speed" parameter
speedSetting = 0.99;

% Camera fps
fps = 206.65;

% Properties of the ramp
rampDurSec = 60;

% Properties of the sinusoid
modDurSecs = 10;
f0 = 0.5;
contrast = 0.5;
background = 0.1;

% Properties of the "settle"
settleDurSec = 10;

% Create the sinusoidal modulation
modSource = sin(linspace(0,2*pi*(modDurSecs/(1/f0)),round(fps*modDurSecs))) * contrast * background + background;

% Assemble the source time series
source = [...
    ones(1,round(fps*settleDurSec)),... % Start at the high light level 10^0;
    logspace(0,-3,round(rampDurSec*fps)), ... % Ramp from the high to the low level
    ones(1,round(fps*settleDurSec))*background,... % Settle at the modulation background;
    modSource, ... % The modulation
    ones(1,round(fps*settleDurSec))*background ... % Settle at the modulation background;
    ];

% Define the time domain of the measure
deltaT = 1/fps;
ts = 0:deltaT:(length(source)-1)*deltaT;

% Set the initial properties of the gain and exposure
gain = 1;
exposure = 37;
signalRange = [0,255];

% Initialize containers to hold results
matlab_gain_store = []; 
cpp_gain_store = [];
matlab_exposure_store = [];
cpp_exposure_store = [];

% Loop through the source
for ii = 1:length(source)
    fprintf("%d/%d\n", ii,length(source)); 

    % Obtain the signal (needed for this simulation, in practice, this is
    % the mean value of the sensor array counts)
    s = source(ii)*exposure*gain;
    s = min(s,signalRange(2));
    s = max(s,signalRange(1));
    signal(ii) = s;

    % Retrieve the results from both the 
    % MATLAB implementation and CPP implementation of AGC
    matlab_retval = AGC(s, gain, exposure, speedSetting); 
    system(sprintf('python3 AGC.py %.3f %.3f %.3f %.3f', s, gain, exposure, speedSetting));
    py_data = py.open('./temp.pkl', 'rb');
    cpp_retval = struct(py.pickle.load(py_data));
    py_data.close()
    system('rm ./temp.pkl'); 

    % Store the adjusted gain and exposure values for plotting
    matlab_gain_store(ii) = matlab_retval.adjusted_gain;
    matlab_exposure_store(ii) = matlab_retval.adjusted_exposure;

    cpp_gain_store(ii) = cpp_retval.adjusted_gain;
    cpp_exposure_store(ii) = cpp_retval.adjusted_exposure; 


end

figure

subplot(4,1,1)
plot(ts,log10(source));
hold on
ylim([-3.5 0.5]);
title('source light intensity')
ylabel('log intensity')
subplot(4,1,2)
plot(ts,matlab_exposure_store, 'DisplayName', 'MATLAB');
plot(ts,cpp_exposure_store, 'DisplayName', 'CPP');
hold on
legend('show')
title('exposure')
ylabel('exposure [μsecs]')
subplot(4,1,3)
plot(ts,matlab_gain_store, 'DisplayName', 'MATLAB');
plot(ts,cpp_gain_store, 'DisplayName', 'CPP');
hold on
legend('show')
title('gain')
ylabel('gain [a.u.]')
subplot(4,1,4)
plot(ts,signal);
hold on
ylim([0 255])
title('signal')
xlabel('time [seconds]')
a = gca();
a.YTick = [0:50:250];