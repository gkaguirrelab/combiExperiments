%% Demo video data fitting

% Which video to analyze
f0 = 25;
NDFilter = '0x2';

% Load the signal
recordingsDir = '/Users/aguirre/Aguirre-Brainard Lab Dropbox/Geoffrey Aguirre/FLIC_data/recordings/';
videoName = sprintf(['realMeasurments_%2.1fhz_' NDFilter 'NDF.avi'],f0);
pixel_array = [1:640*480];
signal = parse_mean_video(fullfile(recordingsDir,videoName), pixel_array);

% Convert the signal into a floating point, contrast vector
signal = double(signal);
signalMean = mean(signal);
signal = signal - mean(signal);
signal = signal / signalMean;

% Define the nominal camerafps
fps0 = 206.65;

% Find the realized fps
fps = findObservedFPS( signal, f0, fps0 );

% Obtain the fit to the data at the stimulus frequency
[r2,amplitude,phase,fit,modelT,signalT] = fourierRegression( signal, f0, fps );

% Plot the resulting fit
plot(modelT,fit,'-r')
hold on
plot(signalT,signal,'.k')
hold off
