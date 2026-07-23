%% test_detectEOGSaccades.m

% Master script to test detectEOGSaccades.m function. 

clear; close all; clc
clear detectEOGSaccades

addpath('/Users/sophiamirabal/Documents/MATLAB/projects/combiExperiments/code/experiments/analyzeEOG/functions')
which detectEOGSaccades

tbUseProject('combiExperiments')
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir = 'FLIC_data';
projectName = 'combiLED';

params = struct;

%% SECTION 1: Find saccades for ONE session of the combiLED EOG calibration data.
% -----------------------------

EOGCalibrationDir = 'EOGCalibration';

% CHANGE SUBJECT ID AND SESSION NUMBER HERE
thisSubj = 'FLIC_0013';
sessionIdx = 3;

fileName = fullfile(dropBoxBaseDir, dropBoxSubDir, projectName, ...
    thisSubj, EOGCalibrationDir, ...
    ['EOGSession' num2str(sessionIdx) 'Cal.mat']);

load(fileName, 'sessionData');

EOGSignal = sessionData.EOGData.response(1,:);
timebase = sessionData.EOGData.timebase;

params = struct;

% CHANGE TO MANIPULATE PARAMETERS ACCORDING TO CHARACTERISTICS OF DATA. 
% LEAVE COMMENTED OUT TO USE DEFAULT DETECTEOGSACCADES.M PARAMETERS. 
% params.velocityThresholdFactor = 8;
% params.onsetThresholdFactor = 3;
% params.minAmplitude = 0.75;
% params.minSaccadeSeparationSec = 0.18;
% params.smoothWindowSec = 0.025;

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


%% SECTION 2: Find saccades for ALL sessions of the combiLED EOG calibration data.
% -----------------------------

% clear; close all; clc
% clear detectEOGSaccades
% which detectEOGSaccades

EOGCalibrationDir = 'EOGCalibration';

subjectID = {'FLIC_0013', 'FLIC_0015', 'FLIC_0017', ...
    'FLIC_0018', 'FLIC_0019', 'FLIC_0020', 'FLIC_0021', 'FLIC_0022', ...
    'FLIC_0027', 'FLIC_0028', 'FLIC_0039', 'FLIC_0042', 'FLIC_0049', ...
    'FLIC_0050', 'FLIC_0051', 'FLIC_1016', 'FLIC_1029', ...
    'FLIC_1030', 'FLIC_1031', 'FLIC_1032', 'FLIC_1034', 'FLIC_1035', ...
    'FLIC_1036', 'FLIC_1038', 'FLIC_1041', 'FLIC_1043', 'FLIC_1044', ...
    'FLIC_1046', 'FLIC_1047', 'FLIC_1048'};

nSessions = 4;

plotDir = fullfile(pwd, 'EOGDetectedSaccadePlots');
if ~exist(plotDir, 'dir')
    mkdir(plotDir);
end

allEventTables = {};

for subjIdx = 1:length(subjectID)

    thisSubj = subjectID{subjIdx};

    for sessionIdx = 1:nSessions

        fileName = fullfile(dropBoxBaseDir, dropBoxSubDir, projectName, ...
            thisSubj, EOGCalibrationDir, ...
            ['EOGSession' num2str(sessionIdx) 'Cal.mat']);

        if ~exist(fileName, 'file')
            warning('File not found: %s', fileName);
            continue
        end

        load(fileName, 'sessionData');

        EOGSignal = sessionData.EOGData.response(1,:);
        timebase = sessionData.EOGData.timebase;

        [events, debug] = detectEOGSaccades(timebase, EOGSignal, params);

        if isempty(events)
            warning('No saccades detected for %s Session %d', thisSubj, sessionIdx);
            continue
        end

        % TABLE
        T = struct2table(events);

        T.subjectID = repmat({thisSubj}, height(T), 1);
        T.sessionIdx = repmat(sessionIdx, height(T), 1);
        T.eventNumber = (1:height(T))';

        T = movevars(T, {'subjectID','sessionIdx','eventNumber'}, 'Before', 1);

        T.absAmplitude = abs(T.amplitude);
        T.absPeakVelocity = abs(T.peakVelocity);
        T.timeSincePrevious = [NaN; diff(T.onsetTime)];

        % ASSESS
        goodDuration = T.duration >= 0.010 & T.duration <= 0.200;
        goodAmplitude = T.absAmplitude >= params.minAmplitude;
        goodVelocity = T.absPeakVelocity >= debug.peakThreshold;
        notDuplicate = isnan(T.timeSincePrevious) | ...
            T.timeSincePrevious >= params.minSaccadeSeparationSec;

        T.passQC = goodDuration & goodAmplitude & goodVelocity & notDuplicate;

        allEventTables{end+1} = T;

        % PLOT
        fig = figure('Visible','off');
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
        legend('Smoothed EOG', 'Onset', 'Peak', 'Offset', 'Location', 'best');

        saveName = fullfile(plotDir, ...
            sprintf('%s_Session%d_DetectedSaccades.png', thisSubj, sessionIdx));

        saveas(fig, saveName);
        close(fig);

        fprintf('%s Session %d: detected %d events, %d passed QC\n', ...
            thisSubj, sessionIdx, height(T), sum(T.passQC));

        clear sessionData EOGSignal timebase events debug T
    end
end

% Combine and save full table
allEvents = vertcat(allEventTables{:});

disp(allEvents(:, {'subjectID','sessionIdx','eventNumber','onsetTime', ...
    'duration','absAmplitude','absPeakVelocity','timeSincePrevious','passQC'}))

save(fullfile(plotDir, 'allDetectedSaccadeEvents.mat'), 'allEvents');
writetable(allEvents, fullfile(plotDir, 'allDetectedSaccadeEvents.csv'));



%% SECTION 3: Find saccades for one real DCPT_SDT trial.
% -----------------------------

% clearvars -except dropBoxBaseDir dropBoxSubDir projectName params
close all; clc

thisSubj = 'FLIC_1048';

lightLevelFolder = 'LightFlux_ND0x5_shifted';  % high light
% lightLevelFolder = 'LightFlux_ND3x0_shifted';  % low light

experimentName = 'DCPT_SDT';

contrastLabel = '0x1';
refFreqHz = 30;
sideLabel = 'hi';
trialIdx = 1;

fileName = fullfile(dropBoxBaseDir, dropBoxSubDir, projectName, ...
    thisSubj, lightLevelFolder, experimentName, ...
    sprintf('%s_LightFlux_%s_cont-%s_refFreq-%gHz_%s.mat', ...
    thisSubj, experimentName, contrastLabel, refFreqHz, sideLabel));

disp(fileName)

if ~exist(fileName, 'file')
    error('File not found. Check subject, light folder, contrast, refFreq, or side label.')
end

load(fileName, 'psychObj');

trialEOG = psychObj.questData.trialData(trialIdx).EOGdata;

EOGSignal = trialEOG.response(1,:);

if isfield(trialEOG, 'timebase')
    timebase = trialEOG.timebase;
elseif isfield(trialEOG, 'Fs')
    timebase = (0:length(EOGSignal)-1) / trialEOG.Fs;
else
    error('Could not find timebase or Fs inside trial EOGdata.')
end

% -----------------------------
% Inspect trial EOG
% -----------------------------
disp(fieldnames(trialEOG))

whos EOGSignal

fprintf('Signal range: %.3f to %.3f\n', ...
    min(EOGSignal), max(EOGSignal));

% RAW EOG SIGNAL PLOT
figure;
plot(timebase,EOGSignal,'r')
xlabel('Time (s)')
ylabel('Raw EOG')
title(sprintf('%s Trial %d Raw EOG', thisSubj, trialIdx))

% -----------------------------
% Run detector
% -----------------------------

% PARAMS TO MANIPULATE
params = struct;
params.velocityThresholdFactor = 1.5;
params.onsetThresholdFactor = 0.75;
params.minAmplitude = 0.01;
params.minSaccadeSeparationSec = 0.02;
params.smoothWindowSec = 0.010;
params.minDurationSec = 0.003;
params.maxDurationSec = 0.200;

[events, debug] = detectEOGSaccades(timebase, EOGSignal, params);

fprintf('Velocity noise estimate = %.3f\n',debug.velocityNoise);
fprintf('Peak threshold = %.3f\n',debug.peakThreshold);
fprintf('Maximum velocity = %.3f\n',max(abs(debug.velocity)));

% Print potential saccades (velocity peaks) 
fprintf('Candidate velocity peaks before rejection = %d\n', length(debug.peakIdx));

% Print detected saccades
fprintf('Detected %d events\n', length(events));

% VELOCITY PLOT
figure;

plot(debug.timebase,debug.velocity)
hold on

yline(debug.peakThreshold,'r--')
yline(-debug.peakThreshold,'r--')

xlabel('Time (s)')
ylabel('Velocity')
title('Velocity Used For Detection')

% T = struct2table(events);
% T.eventNumber = (1:height(T))';
% T = movevars(T, 'eventNumber', 'Before', 1);
% T.absAmplitude = abs(T.amplitude);
% T.absPeakVelocity = abs(T.peakVelocity);
% T.timeSincePrevious = [NaN; diff(T.onsetTime)];
% 
% disp(T(:, {'eventNumber','onsetTime','duration', ...
%     'amplitude','absAmplitude','peakVelocity','absPeakVelocity', ...
%     'strength','timeSincePrevious'}))

% DETECTED SACCADES PLOT
figure;
plot(debug.timebase, debug.EOGSmooth, 'r');
hold on

for i = 1:length(events)
    xline(events(i).onsetTime, 'g--', 'LineWidth', 1);
    xline(events(i).peakTime, 'r:', 'LineWidth', 1);
    xline(events(i).offsetTime, 'b--', 'LineWidth', 1);
end

xlabel('Time (s)');
ylabel('EOG amplitude');
title(sprintf('%s %s %s %sHz %s trial %d: detected saccades', ...
    thisSubj, lightLevelFolder, contrastLabel, num2str(refFreqHz), sideLabel, trialIdx));
if isempty(events)
    legend('Smoothed EOG');
else
    legend('Smoothed EOG', 'Onset', 'Peak', 'Offset');
end