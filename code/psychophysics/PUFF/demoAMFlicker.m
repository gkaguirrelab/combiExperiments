
% Define the calibration files
calSubDir = 'PUFF';
calFileName = 'CombiLED-B_split3mm_lightPuff_ND0.mat';

% Load the cal file
cal = loadCalByName(calFileName, calSubDir);

% Open a CombiLEDcontrol object
obj = CombiLEDcontrol('verbose',false);

% Update the gamma table
obj.setGamma(cal.processedData.gammaTable);

%% Define an amplitude modulated flicker

% Define the FM fundamental
obj.setWaveformIndex(1);
obj.setFrequency(24);
obj.setContrast(1);

% Define the AM envelope
obj.setAMIndex(1);
obj.setAMFrequency(1/60);

% We are going to leave this nuance for later
%{
    % Duration in seconds
    obj.setDuration(60);
    % Subject the stimulus onset and offset to a half-cosine ramp
    obj.setRampIndex(1); % half-cosine windowing
    obj.setRampDuration(2); % 2 second ramp on / off
%}

% Pause then present the modulation. Continue until key press
fprintf('Press any key to start, and then stop, the modulation...')
pause
obj.startModulation;
fprintf('modulating...')
pause
fprintf('done\n')
obj.stopModulation;
obj.goDark;
