%% test_detectEOGSaccades.m

clear; close all; clc
clear detectEOGSaccades
which detectEOGSaccades

dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');

dropBoxSubDir = 'FLIC_data';
projectName = 'combiLED';
EOGCalibrationDir = 'EOGCalibration';

thisSubj = 'FLIC_0013';
sessionIdx = 3;

fileName = fullfile(dropBoxBaseDir, dropBoxSubDir, projectName, ...
    thisSubj, EOGCalibrationDir, ...
    ['EOGSession' num2str(sessionIdx) 'Cal.mat']);

load(fileName, 'sessionData');

EOGSignal = sessionData.EOGData.response(1,:);
timebase = sessionData.EOGData.timebase;

params = struct;
params.velocityThresholdFactor = 8;
params.onsetThresholdFactor = 3;
params.minAmplitude = 0.75;
params.minSaccadeSeparationSec = 0.18;
params.smoothWindowSec = 0.025;

[events, debug] = detectEOGSaccades(timebase, EOGSignal, params);

% TABLE
T = struct2table(events);

T.eventNumber = (1:height(T))';
T = movevars(T, 'eventNumber', 'Before', 1);

T.absAmplitude = abs(T.amplitude);
T.absPeakVelocity = abs(T.peakVelocity);
T.timeSincePrevious = [NaN; diff(T.onsetTime)];

disp(T(:, {'eventNumber','onsetTime','duration', ...
    'amplitude','absAmplitude','peakVelocity','absPeakVelocity', ...
    'strength','timeSincePrevious'}))

% ASSESS
goodDuration = T.duration >= 0.010 & T.duration <= 0.200;
goodAmplitude = T.absAmplitude >= 1.5;
goodVelocity = T.absPeakVelocity >= debug.peakThreshold;
notDuplicate = isnan(T.timeSincePrevious) | T.timeSincePrevious >= 0.25;

T.passQC = goodDuration & goodAmplitude & goodVelocity & notDuplicate;

disp(T(:, {'eventNumber','onsetTime','duration','absAmplitude', ...
    'absPeakVelocity','timeSincePrevious','passQC'}))

% PLOT
figure;
plot(debug.timebase, debug.EOGSmooth, 'k');
hold on

for i = 1:length(events)
    xline(events(i).onsetTime, 'g--', 'LineWidth', 1);
    xline(events(i).peakTime, 'r:', 'LineWidth', 1);
    xline(events(i).offsetTime, 'b--', 'LineWidth', 1);
end

xlabel('Time (s)');
ylabel('EOG amplitude');
title(sprintf('%s Session %d: detected EOG saccades', thisSubj, sessionIdx));
legend('Smoothed EOG', 'Onset', 'Peak', 'Offset');