% Going to use FLIC_0018 Session 2 as our EOG calibration example

EOGCal = load('/Users/rubybouh/Aguirre-Brainard Lab Dropbox/Ruby Bouhassira/FLIC_data/combiLED/FLIC_0018/EOGCalibration/EOGSession2Cal.mat', ...
    'sessionData');

% Parameters & timing
fs = sessionData.Fs; % sampling rate is 48000 Hz
timebase = sessionData.EOGData.timebase;
Neog = length(timebase);
preSilence = 2.0;    % seconds before first spoken command
gap = 0.25;          % seconds between spoken commands
cmdValues  = repmat([0 -1 0 1], 1, 3);  % 12 commands (center, left, center, right repeated 3x)
nCmd = length(cmdValues);  

% Duration of each command in seconds
Tcmd = (timebase(end) - preSilence - (nCmd-1)*gap) / nCmd;

% Initialize target square wave vector
target = zeros(Neog,1);  

% Fill in commands using time comparisons
tStart = preSilence;
for k = 1:nCmd
    tEnd = tStart + Tcmd;
    
    % Find indices in timebase that fall within this command
    idx = find(timebase >= tStart & timebase < tEnd);
    
    % Assign command value
    target(idx) = cmdValues(k);
    
    % Move to next command (include gap)
    tStart = tEnd + gap;
end

% Plotting
figure
plot(timebase, target, 'LineWidth', 2)
ylim([-1.5 1.5])
yticks([-1 0 1])
% yticklabels({'Left','Center','Right'})
xlabel('Time (s)')
ylabel('Eye Position')
title('Square Wave Target Signal')

