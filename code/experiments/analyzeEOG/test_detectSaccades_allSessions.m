%% test_detectEOGSaccades_allSessions.m

clear; close all; clc
clear detectEOGSaccades
which detectEOGSaccades

dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');

dropBoxSubDir = 'FLIC_data';
projectName = 'combiLED';
EOGCalibrationDir = 'EOGCalibration';

subjectID = {'FLIC_0013', 'FLIC_0015', 'FLIC_0017', ...
    'FLIC_0018', 'FLIC_0019', 'FLIC_0020', 'FLIC_0021', 'FLIC_0022', ...
    'FLIC_0027', 'FLIC_0028', 'FLIC_0039', 'FLIC_0042', 'FLIC_0049', ...
    'FLIC_0050', 'FLIC_0051', 'FLIC_1016', 'FLIC_1029', ...
    'FLIC_1030', 'FLIC_1031', 'FLIC_1032', 'FLIC_1034', 'FLIC_1035', ...
    'FLIC_1036', 'FLIC_1038', 'FLIC_1041', 'FLIC_1043', 'FLIC_1044', ...
    'FLIC_1046', 'FLIC_1047', 'FLIC_1048'};

nSessions = 4;

params = struct;
params.velocityThresholdFactor = 12;
params.onsetThresholdFactor = 4;
params.minAmplitude = 1.5;
params.minSaccadeSeparationSec = 0.25;

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