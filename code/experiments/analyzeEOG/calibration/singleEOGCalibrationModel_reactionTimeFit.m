%% singleEOGCalibrationModel_reactionTimeFit.m

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


% 'FLIC_0007' is missing session 3 and is excluded
% 'FLIC_1010' is missing session 2 and is excluded
subjectID = {'FLIC_0013', 'FLIC_0015', 'FLIC_0017', ...
    'FLIC_0018', 'FLIC_0019', 'FLIC_0020', 'FLIC_0021', 'FLIC_0022', ...
    'FLIC_0027', 'FLIC_0028', 'FLIC_0039', 'FLIC_0042', 'FLIC_0049', ...
    'FLIC_0050', 'FLIC_0051', 'FLIC_1016', 'FLIC_1029', ...
    'FLIC_1030', 'FLIC_1031', 'FLIC_1032', 'FLIC_1034', 'FLIC_1035', ...
    'FLIC_1036', 'FLIC_1038', 'FLIC_1041', 'FLIC_1043', 'FLIC_1044', ...
    'FLIC_1046', 'FLIC_1047', 'FLIC_1048'};

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
        fs = sessionData.Fs; % sampling rate is 48000 Hz
        fc = 0.12;                  % Filter cut-off frequency (Hz)
        timebase = sessionData.EOGData.timebase;
        Neog = length(timebase);
        cmdValues  = repmat([0 -1 0 1], 1, 3);  % 12 commands (center, left, center, right repeated 3x)
        nCmd = length(cmdValues);  

        % Test possible reaction times
        reactionTimeList = 0.2:0.05:0.8;

        bestError = inf;

        for rtIdx = 1:length(reactionTimeList)

            reactionTime_temp = reactionTimeList(rtIdx);

            % Generate model using this candidate reaction time
            [x_temp, y_temp] = generateEOGModel(timebase, onsets, cmdValues, reactionTime_temp, fc);

            % Define valid fitting window for this candidate reaction time
            tStart_temp = onsets(1) + reactionTime_temp;
            tEnd_temp   = offsets(end) + reactionTime_temp;
            validIdx_temp = timebase >= tStart_temp & timebase <= tEnd_temp;

            EOGSignalValid_temp = EOGSignal(validIdx_temp);
            yValid_temp = y_temp(validIdx_temp);

            % Force column vectors
            yValid_temp = yValid_temp(:);
            EOGSignalValid_temp = EOGSignalValid_temp(:);

            % Fit beta normally for this candidate reaction time
            beta_temp = yValid_temp \ EOGSignalValid_temp;

            % Calculate fit error for this candidate reaction time
            y_scaled_temp = beta_temp * yValid_temp;
            error_temp = sqrt(mean((EOGSignalValid_temp - y_scaled_temp).^2));

            % Keep the reaction time that gives the lowest error
            if error_temp < bestError
                bestError = error_temp;
                reactionTime = reactionTime_temp;
                x = x_temp;
                y = y_temp;
                beta = beta_temp;
                validIdx = validIdx_temp;
            end
        end

        % Define final censored data/model using the best reaction time
        EOGSignalValid = EOGSignal(validIdx);
        yValid = y(validIdx);

        % Force column vectors
        yValid = yValid(:);
        EOGSignalValid = EOGSignalValid(:);
        y = y(:);
        EOGSignal = EOGSignal(:);

        % Scaled model using the best reaction time and its fitted beta
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
        title(sprintf('%s Session %d: EOG Model Fit, RT = %.2f s', thisSubj, sessionIdx, reactionTime));        
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
function [x, y] = generateEOGModel(timebase, onsets, cmdValues, reactionTime, fc)
    % Initialize target square wave vector
    Neog = length(timebase);
    nCmd = length(cmdValues);
    x = zeros(Neog,1);
    % For subjects that exhibit early return-to-center behavior
    % earlyReturn = 0.5;
    % earlyOnsets = onsets - earlyReturn;
    for k = 1:nCmd
        if k < nCmd && mod(k,2) == 0 % check if this is a not a center command (even index)
            % If it is not a "center" command, move the next onset to an earlier time (subject returns to center early)
            idx = timebase >= (onsets(k) + reactionTime) & timebase < (onsets(k+1) + reactionTime);
        elseif k < nCmd && mod(k,2) ~= 0 % after a center command, subject waits until they hear the next command
            idx = timebase >= (onsets(k) + reactionTime) & timebase < (onsets(k+1) + reactionTime);
        else
            idx = timebase >= (onsets(k) + reactionTime);
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
