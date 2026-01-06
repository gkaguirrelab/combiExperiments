% Going to use FLIC_0018 Session 1 as our EOG calibration example

% It does not matter which EOG file is used here
% EOGCal = load('/Users/rubybouh/Aguirre-Brainard Lab Dropbox/Ruby Bouhassira/FLIC_data/combiLED/FLIC_0018/EOGCalibration/EOGSession1Cal.mat', ...
%     'sessionData');

EOGCal = load('/Users/rubybouh/Documents/EOGSession1Cal.mat', 'sessionData');
sessionData = EOGCal.sessionData; 

% Parameters & timing
fs = sessionData.Fs; % sampling rate is 48000 Hz
fc = 2.5;                  % Filter cut-off frequency (Hz)
timebase = sessionData.EOGData.timebase;
Neog = length(timebase);
preSilence = 2.0;    % seconds before first spoken command
gap = 0.25;          % seconds between spoken commands
cmdValues  = repmat([0 -1 0 1], 1, 3);  % 12 commands (center, left, center, right repeated 3x)
nCmd = length(cmdValues);  

% Duration of each command in seconds
Tcmd = (timebase(end) - preSilence - (nCmd-1)*gap) / nCmd;

% Initialize target square wave vector
x = zeros(Neog,1);  

% Fill in commands using time comparisons
tStart = preSilence;
for k = 1:nCmd
    tEnd = tStart + Tcmd;
    
    % Find indices in timebase that fall within this command
    idx = find(timebase >= tStart & timebase < tEnd);
    
    % Assign command value
    x(idx) = cmdValues(k);
    
    % Move to next command (include gap)
    tStart = tEnd + gap;
end

% Define the High-Pass Filter Transfer Function
% H(s) = s / (s + omega_c) where omega_c = 2 * pi * fc
s = tf('s');
omega_c = 2 * pi * fc;
H = s / (s + omega_c);

% Simulate the System Response
y = lsim(H, x, timebase);

% Visualization
figure;
plot(timebase, x, 'k--', 'LineWidth', 1.5); hold on;
plot(timebase, y, 'r', 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('Amplitude');
title(['High-Pass Filter Response (f_c = ', num2str(fc), ' Hz)']);
legend('Input Square Wave', 'Filtered Output');
xlim([0 25]);
ylim([-1.5 1.5]);

