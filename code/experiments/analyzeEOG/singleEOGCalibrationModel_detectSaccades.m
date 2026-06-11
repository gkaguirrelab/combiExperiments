%% Extract timing of "left" "right" "center" commands from audio file

[y, fs] = audioread('EOGCalInstructions.mp3');

if size(y,2) > 1
    y = mean(y,2);   % converts stereo audio to mono
end

tAudio = (0:length(y)-1)' / fs;

a = abs(y);
a = movmean(a, round(0.02*fs));  % 20 ms smoothing
a = a / max(a);                  % normalize

speech = a > 0.08;   % threshold

minGap = 0.15;   % seconds (shorter than real pause)
speech = imclose(speech, ones(round(minGap*fs),1));

d = diff([0; speech; 0]);

onsets = find(d == 1) / fs;
offsets = find(d == -1) / fs;

%%
close all;

% Define subjects/sessions to plot
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir = 'FLIC_data';
projectName = 'combiLED';
EOGCalibrationDir = 'EOGCalibration';

subjectID = {'FLIC_0013', 'FLIC_0015', 'FLIC_0017', ...
    'FLIC_0018', 'FLIC_0019','FLIC_0020', 'FLIC_0021', 'FLIC_0022', 'FLIC_0027',... 
    'FLIC_0028','FLIC_0039', 'FLIC_0042'};     

nSubj = length(subjectID);
nSessions = 4;

% Store fit error for each subject/session
RMSEMatrix = zeros(nSubj, nSessions);

% Save plots in a folder so directory isn't flooded. 
plotDir = fullfile(pwd, 'EOGModelFitPlots');
if ~exist(plotDir, 'dir')
    mkdir(plotDir);
end

for subjIdx = 1:nSubj

    thisSubj = subjectID{subjIdx};

    for sessionIdx = 1:nSessions

        % Load this subject/session calibration file
        subjectDir = fullfile(dropBoxBaseDir, dropBoxSubDir, projectName, thisSubj);
        dataDir = fullfile(subjectDir, EOGCalibrationDir);
        fileName = fullfile(dataDir, ['EOGSession' num2str(sessionIdx) 'Cal.mat']);

        load(fileName, 'sessionData');

        EOGSignal = sessionData.EOGData.response(1,:);
           
        % % UNCOMMENT TO SELECT ONE FILE
        % Select EOG file and extract the data
        % load('[INSERT PATH TO FILE HERE]');
        % EOGSignal = sessionData.EOGData.response(1,:); 
        
        % Parameters & timing
        fs = sessionData.Fs;        % sampling rate is 48000 Hz
        fc = 0.12;                  % Filter cut-off frequency (Hz)
        timebase = sessionData.EOGData.timebase;
        Neog = length(timebase);
        cmdValues  = repmat([0 -1 0 1], 1, 3);  % 12 commands (center, left, center, right repeated 3x)
        nCmd = length(cmdValues);  

        % Detect actual saccade times from large changes in EOG amplitude
        detectedSaccadeTimes = detectSaccadeTimes(timebase, EOGSignal, onsets, cmdValues);
        
        % Generate model using detected saccade times instead of fixed reaction time
        [x, y] = generateEOGModelDetected(timebase, detectedSaccadeTimes, cmdValues, fc);
        
        % Define censoring window based on detected saccade timing
        tStart = detectedSaccadeTimes(1);
        tEnd   = detectedSaccadeTimes(end);
        validIdx = timebase >= tStart & timebase <= tEnd;
        
        EOGSignalValid = EOGSignal(validIdx);
        yValid = y(validIdx);
        
        % Force column vectors
        yValid = yValid(:);
        EOGSignalValid = EOGSignalValid(:);
        y = y(:);
        EOGSignal = EOGSignal(:);
        
        % Fit beta using model based on detected saccade timing
        beta = yValid \ EOGSignalValid;
        
        % Scaled model
        y_scaled = beta * y;

        % Calculate fit error for this subject/session
        RMSE = sqrt(mean((EOGSignalValid - y_scaled(validIdx)).^2));

        % Store RMSE in matrix
        RMSEMatrix(subjIdx, sessionIdx) = RMSE;
        
        % Visualization of scaled model that fits the data
        figure;
        clf;
        hold on;

        % Plot in gray first, indicating data that has been censored out 
        plot(timebase, EOGSignal, 'Color', [0.7 0.7 0.7], 'LineWidth', 1.5); hold on;
        plot(timebase, y_scaled,  'Color', [0.7 0.7 0.7], 'LineWidth', 1.7);

        % Plot valid data on top
        plot(timebase(validIdx), EOGSignalValid, 'b', 'LineWidth', 1.5);
        plot(timebase(validIdx), y_scaled(validIdx), 'r', 'LineWidth', 1.7);
        xlabel('Time (s)');
        ylabel('Amplitude');
        title(sprintf('%s Session %d: EOG Model Fit, detected saccades', thisSubj, sessionIdx)); 

        % Mark detected saccade times
        for k = 1:length(detectedSaccadeTimes)
            xline(detectedSaccadeTimes(k), 'm--');
        end

        legend('','','EOG Data', 'Scaled Model');
        xlim([0 25]);

        % Save plot for this subject/session
        saveName = fullfile(plotDir, sprintf('%s_Session%d_EOGModelFit.png', thisSubj, sessionIdx));
        saveas(gcf, saveName);

        hold off;
        close(gcf);

        clear sessionData
    end
end

%% Display RMSE results

% Convert RMSE matrix into a readable table
RMSETable = array2table(RMSEMatrix, ...
    'VariableNames', {'Session1', 'Session2', 'Session3', 'Session4'}, ...
    'RowNames', subjectID);

disp('RMSE fit error for each subject/session:')
disp(RMSETable)

disp('Mean RMSE across all subjects/sessions:')
disp(mean(RMSEMatrix(:)))

%%
function detectedSaccadeTimes = detectSaccadeTimes(timebase, EOGSignal, onsets, cmdValues)

    nCmd = length(onsets);
    detectedSaccadeTimes = nan(size(onsets));

    % Minimum EOG change required to count as a command-related movement
    ampThreshold = 3.0;  % adjust based on plots

    for k = 1:nCmd

        % Search after command onset
        searchIdx = timebase >= onsets(k) + 0.1 & timebase <= onsets(k) + 1.2;

        % Baseline just before command onset
        baseIdx = timebase >= onsets(k) - 0.1 & timebase <= onsets(k);
        baseline = median(EOGSignal(baseIdx));

        % Signal change relative to command-time baseline
        deltaEOG = EOGSignal - baseline;

        if cmdValues(k) > 0
            % Expected rightward / positive movement
            candidateIdx = find(searchIdx & deltaEOG > ampThreshold, 1, 'first');

        elseif cmdValues(k) < 0
            % Expected leftward / negative movement
            candidateIdx = find(searchIdx & deltaEOG < -ampThreshold, 1, 'first');

        else
            % Expected return toward center; direction depends on current baseline
            candidateIdx = find(searchIdx & abs(deltaEOG) > ampThreshold, 1, 'first');
        end

        if ~isempty(candidateIdx)
            detectedSaccadeTimes(k) = timebase(candidateIdx);
        else
            detectedSaccadeTimes(k) = onsets(k) + 0.5;
        end
    end
end


function [x, y] = generateEOGModelDetected(timebase, detectedSaccadeTimes, cmdValues, fc)

    % Build square-wave model using detected saccade times
    Neog = length(timebase);
    nCmd = length(cmdValues);
    x = zeros(Neog,1);

    for k = 1:nCmd
        if k < nCmd
            idx = timebase >= detectedSaccadeTimes(k) & timebase < detectedSaccadeTimes(k+1);
        else
            idx = timebase >= detectedSaccadeTimes(k);
        end

        x(idx) = cmdValues(k);
    end

    % High-pass filter
    s = tf('s');
    omega_c = 2 * pi * fc;
    H = s / (s + omega_c);

    % Simulate system response
    y = lsim(H, x, timebase);
end
