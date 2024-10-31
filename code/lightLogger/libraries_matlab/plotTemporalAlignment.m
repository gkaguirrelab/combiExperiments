% This is a short script illustrating how to conduct temporal alignment between two sensors. 
% When the world cam is working, this will be made into a function that will accept the different
% sensors as input.


% Define the frequency 
frequency = 0.1;

% Read in the MS data frames
path_to_MS_readings = "/Volumes/EXTERNAL1/pupilAndMS_0.1hz_0NDF/pupilAndMS_0.1hz_0NDF_MS_readings";
[AS_t, TS_t, LS_t, temp_t] = readInMSDataFiles(path_to_MS_readings);

% Construct the MS signal 
signal_ms = double(TS_t{:,2}); % Change this depending on which sensor to use 
signal_contrast_ms = (signal_ms - mean(signal_ms)) / mean(signal_ms);

% Construct the Pupil signal 
path_to_pupil_readings = "/Volumes/EXTERNAL1/pupilAndMS_0.1hz_0NDF/pupilAndMS_0.1hz_0NDF_pupil";
signal_pupil = parse_mean_frame_array_buffer(path_to_pupil_readings);
signal_contrast_pupil = (signal_pupil - mean(signal_pupil)) / mean(signal_pupil);

% Fit the MS 
[r2_ms,~,phase_ms,fit_ms,modelT_ms,signalT_ms] = fourierRegression(signal_contrast_ms, 0.1, 0.9860, 1000 );

% Fit the pupil 
[r2_pupil,~,phase_pupil,fit_pupil,modelT_pupil,signalT_pupil] = fourierRegression(signal_contrast_pupil, 0.1, 119.8827, 1000 );

% Plot the observed data and the fits 
figure ; 
%plot(signalT_ms, signal_contrast_ms, '-x', 'DisplayName', 'Signal TS');
hold on ;
plot(modelT_ms, fit_ms, '-x', 'DisplayName', 'Fit TS');
%plot(signalT_pupil, signal_contrast_pupil, '-o', 'DisplayName', 'Signal Pupil');
plot(modelT_pupil, fit_pupil, '-o', 'DisplayName', 'Fit Pupil');

% Calculate the phase difference in radians 
phase_difference_rad = phase_pupil - phase_ms;
   
% Convert to seconds 
phase_difference_sec = phase_difference_rad/(2*pi*frequency);

% Plot the adjusted Pupil data
plot(signalT_pupil - phase_difference_sec, signal_contrast_pupil, '-.', 'LineWidth', 2, 'DisplayName', 'Adjusted Pupil');

% Label the plot 
legend show 
title('TS and Pupil Cam Superimposed');
xlabel('Time [seconds]');
ylabel('Contrast');