%{

This is an extension for the function fit_source_modulation in Camera_util.py, 
as the calulation + plotting must be done in MATLAB to achieve the correct results. 
That function uses the commandline to run this script and resumes exiting after it 
has finished. The two scripts communicate via objects given to each other. That function 
will produce temp.pkl, a saved Python dict object, that this script reads in. This script 
will produce temp.mat after it is finished executing, which the Python script reads in. 
%}

% Import the Python library used to save objects (such as Dictionary)
pickle = py.importlib.import_module('pickle');

% Read in the temp data file
data_file = py.open('temp.pkl', 'rb');

% Parse the temp data file
py_data = struct(pickle.load(data_file));

% Extract relevant information from the struct
signal = double(py_data.signal);
light_level = char(py_data.light_level);
f0 = double(py_data.frequency);
fps = double(py_data.fps);
elapsed_seconds = double(py_data.elapsed_seconds);
secsPerMeasure = double(py_data.secsPerMeasure);

% Close the file
data_file.close();

% Perform the fitting routine
signalT = 0:secsPerMeasure:elapsed_seconds-secsPerMeasure; 

sig_mean = mean(signal);
signal = signal - mean(signal);  % freq is the source flicker freq in Hz. Signal is the vector of measures for a channel
% sampling frequency of signal 
fs = 1./secsPerMeasure;
modeldT = 0.001; 
modelT = 0:modeldT:elapsed_seconds - modeldT; 
% Set up the regression matrix
X = [];
X(:,1) = sin(  modelT./(1/f0).*2*pi );
X(:,2) = cos(  modelT./(1/f0).*2*pi );

% Perform the fit
y = interp1(signalT,signal,modelT,'nearest','extrap')';
b = X\y;

fit = X * b;  % high temporal resolution fit,

amplitude  = norm(b);
phase = -atan(b(2)/b(1));


% Plot the signal versus fit values
figure ;

plot(signalT,signal+sig_mean, '-o');
hold on; 
title(sprintf("Source vs Fit %sNDF %0.1fhz", light_level, f0))
plot(modelT,fit+sig_mean, '-o');
xlabel('Time (seconds)');
ylabel('Counts');
legend('Signal','Fit');
hold off; 

% Save the calculated information for Python 
% to reproduce the plots and continue other measures 
temp_data.signalT = signalT; 
temp_data.signal = signal; 
temp_data.sig_mean = sig_mean; 
temp_data.modelT = modelT; 
temp_data.fit = fit; 
temp_data.amplitude = amplitude; 
temp_data.phase = phase; 
save('~/Documents/MATLAB/projects/combiExperiments/code/minispect/raspberry_pi_firmware/utility/temp.mat', 'temp_data');

thing1 = signal + sig_mean; 
save('geoff_signal.mat', "thing1");

thing2 = fit+sig_mean; 
save('geoff_fit.mat', 'thing2');

% Pause for 10 seconds for time to observe
pause(10); 

% Close all figures
close all; 

% Exit MATLAB and return execution control to Python
exit ; 