function plotTemporalAlignment(experiment_path, frequency, NDF, sensors_to_align)

    % Parse and validate the input arguments 
    arguments
        % The path to the suprafolder containing all of the chunks of a given experiment
        experiment_path {mustBeText};
        
        % The frequency the experiment was captured at 
        frequency (1,1) {mustBeNumeric};

        % The NDF level the experiment was captured at 
        NDF (1,1) {mustBeNumeric};

        % A boolean array of which sensors to align. 
        % [MS, WorldCam, Pupil, Sunglasses]. The indices 
        % where this is true are the sensors that are aligned 
        sensors_to_align (1,4) {mustBeLogical};

    end

    % Load in the Python helper functions 
    current_dir = pwd(); % Record the current working directory
    path_to_here = mfilename('fullpath'); % Record the path to the current file

    % Derive the path to the lightlogger directory from the current file
    [lightlogger_dir, ~, ~] = fileparts(fileparts(path_to_here));

    % Generate the path to the raspberry pi utility directory  and cd into it 
    pi_util_dir = fullfile(lightlogger_dir, 'raspberry_pi_firmware', 'utility');
    cd(pi_util_dir); 

    % Load in the raspberry pi utility library 
    pi_util = py.importlib.import_module('Pi_util');

    % Return to the original working directory 
    cd(current_dir);

    % Load in all of the info per chunk using the Python helper function
    % and convert both the overall list and the sublists into cell arrays
    chunks = cellfun(@(x) string(cell(x)), cell(pi_util.parse_chunks(experiment_path)), 'UniformOutput', false);

    % Plot a single chunk all of the sensors on that plot 
    % on a common time scale and then you have already applied the phase 
    % correction
    % Then show this for all of the chunks

    % Do this for 5hz and 0.1hz 

    % Iterate over the chunks
    for cc = 1:numel(chunks)
        fprintf('Processing chunk: %d\n', cc);

        % Retrieve the paths from the chunk
        [MS_path, pupil_path, sunglasses_path, world_path, world_settings_path] = chunks{cc}{:};
 
        % Initialize an array of signals to match 

        % If the first index is set, then load in the MS data
        if(sensors_to_align(1) == true)
            [AS_t, TS_t, LS_t, temp_t] = readInMSDataFiles(MS_path);

            % Extract the relevant channels from the light sensing chips of the MS 
            AS_signal = AS_t(:, 2);
            TS_signal = TS_t(:, 2);
            
            AS_signal_contrast = (AS_signal - mean(AS_signal)) / mean(AS_signal);
            TS_signal_contrast = (TS_signal - mean(TS_signal)) / mean(TS_signal);

        end

        % If the second index is set, then load in the world cam data
        if(sensors_to_align(2) == true)
            world_signal = parse_mean_frame_array_buffer(world_path);
            world_signal_contrast = (world_signal - mean(world_signal)) / mean(world_signal); 

        end

        % If the third index is set, then load in the pupil cam data
        if(sensors_to_align(3) == true)
            pupil_signal = parse_mean_frame_array_buffer(pupil_path);

            % Exclude the first 2 seconds of the pupil signal due to the initialization period 
            pupil_signal = pupil_signal(240:end); % TODO: change this 240 to retrieving CAM_FPS from the Python file
            
            pupil_signal_contrast = (pupil_signal - mean(pupil_signal)) / mean(pupil_signal); 

        end

        % If the fourth index is set, then load in the sunglasses data
        if(sensors_to_align(4) == true)
            sunglasses_t = readInSunglassesReadings(sunglasses_path);

        end

        % Now that we have all the data, we are going to match combinations (as opposed to permutations)
        % of sensors. 

    end

end

% Utility functions 
function mustBeLogical(x)
    if(~islogical(x))
        error('Argument (sensors_to_align) must be logical');
    end

end 

% This is a short script illustrating how to conduct temporal alignment between two sensors. 
% When the world cam is working, this will be made into a function that will accept the different
% sensors as input.

%{
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
%}