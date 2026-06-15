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

% TOGGLE analysis sections on/off
doModelFit = false;
doTrialAverage = true;

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

avgPlotDir = fullfile(pwd, 'EOGAverageTrialPlots');
if ~exist(avgPlotDir, 'dir')
    mkdir(avgPlotDir);
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

        % FIT THE DATA W/ MODEL
        if doModelFit
        
            % Generate model using detected saccade times
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
        end

        % AVERAGE ACROSS TRIALS FOR EACH SESSION
        % 
        % This section averages repeated saccade trials within a single 
        % calibration session. Each trial is baseline-subtracted using the 
        % mean EOG signal immediately before the saccade so that all trials begin
        % from a common reference value near zero. 
        % 
        % Trials are grouped by movement type (center→left, left→center,
        % center→right, right→center) and averaged separately. The resulting plot
        % shows the average EOG response for each saccade type within a
        % session, where t = 0 corresponds to the detected saccade onset. 
        % 
        % The plot reflects how the EOG signal changes relative to
        % the start of each movement rather than the absolute eye position.
        if doTrialAverage

            % Extract and average repeated saccade trials within this session
            % Each trial becomes a short segment lasting 2.25 sec total
            tBefore = 0.25;
            tAfter = 1.00;

            [eventTimebase, meanByType, trialsByType] = averageSaccadeTrials( ...
                timebase, EOGSignal, detectedSaccadeTimes, cmdValues, tBefore, tAfter);

            figure;
            clf;
            hold on;
            
            % Center -> Left: individual trials faint, average bold
            for i = 1:size(trialsByType.centerToLeft,2)
                plot(eventTimebase, trialsByType.centerToLeft(:,i), ...
                    'Color', [0.6 0.8 1], 'LineWidth', 0.75);
            end
            h1 = plot(eventTimebase, meanByType.centerToLeft, ...
                'Color', [0 0.45 0.74], 'LineWidth', 3);
            
            % Left -> Center
            for i = 1:size(trialsByType.leftToCenter,2)
                plot(eventTimebase, trialsByType.leftToCenter(:,i), ...
                    'Color', [0.7 1 0.7], 'LineWidth', 0.75);
            end
            h2 = plot(eventTimebase, meanByType.leftToCenter, ...
                'Color', [0 0.6 0], 'LineWidth', 3);
            
            % Center -> Right
            for i = 1:size(trialsByType.centerToRight,2)
                plot(eventTimebase, trialsByType.centerToRight(:,i), ...
                    'Color', [1 0.7 0.7], 'LineWidth', 0.75);
            end
            h3 = plot(eventTimebase, meanByType.centerToRight, ...
                'Color', [0.85 0.1 0.1], 'LineWidth', 3);
            
            % Right -> Center
            for i = 1:size(trialsByType.rightToCenter,2)
                plot(eventTimebase, trialsByType.rightToCenter(:,i), ...
                    'Color', [1 0.85 0.6], 'LineWidth', 0.75);
            end
            h4 = plot(eventTimebase, meanByType.rightToCenter, ...
                'Color', [0.9 0.5 0], 'LineWidth', 3);
            
            % Reference lines
            xline(0, 'w--', 'LineWidth', 1.5);
            yline(0, 'w:', 'LineWidth', 1);
            
            xlabel('Time from detected saccade onset (s)');
            ylabel('Baseline-subtracted EOG amplitude');
            title(sprintf('%s Session %d: Average EOG by Saccade Type', thisSubj, sessionIdx));
            
            legend([h1 h2 h3 h4], ...
                sprintf('Center to Left mean (n=%d)', size(trialsByType.centerToLeft,2)), ...
                sprintf('Left to Center mean (n=%d)', size(trialsByType.leftToCenter,2)), ...
                sprintf('Center to Right mean (n=%d)', size(trialsByType.centerToRight,2)), ...
                sprintf('Right to Center mean (n=%d)', size(trialsByType.rightToCenter,2)), ...
                'Location', 'best');
            
            xlim([-tBefore tAfter]);
            
            saveName = fullfile(avgPlotDir, sprintf('%s_Session%d_AverageSaccades.png', thisSubj, sessionIdx));
            saveas(gcf, saveName);
            
            hold off;
            close(gcf);
            
        end

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
            % Backtrack from threshold crossing to estimate movement onset
            onsetThreshold = 0.15 * ampThreshold;
        
            backIdx = candidateIdx;
        
            while backIdx > 1 && abs(deltaEOG(backIdx)) > onsetThreshold
                backIdx = backIdx - 1;
            end
        
            detectedSaccadeTimes(k) = timebase(backIdx);
    
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


function [eventTimebase, meanByType, trialsByType] = averageSaccadeTrials(timebase, EOGSignal, detectedSaccadeTimes, cmdValues, tBefore, tAfter)
% eventTimeBase :   x-axis for the trial plot (-0.25 to 2.00 sec approx, 
%                   where 0 is the detected saccade time)
% meanByType    :   stores the average waveform for each of the trial 
%                   groups.
% trialsByType  :   stores the individual trial snippets, separated into
%                   groups (centerToLeft, leftToCenter, centerToRight,
%                   RightToCenter)

    % Estimate the sampling rate from EOG timebase
    fsEstimate = 1 / mean(diff(timebase));
    
    % Convert seconds into number of samples
    nBefore = round(tBefore * fsEstimate);
    nAfter  = round(tAfter  * fsEstimate);
    
    % Create the x-axis for every extracted trial
    eventTimebase = (-nBefore:nAfter) / fsEstimate;
    
    % Initialize containers for extracted trial snippets
    trialsByType.centerToLeft = [];
    trialsByType.leftToCenter = [];
    trialsByType.centerToRight = [];
    trialsByType.rightToCenter = [];
    
    % Loop through each command transition 
    for k = 2:length(cmdValues)
    
        prevCmd = cmdValues(k-1);
        thisCmd = cmdValues(k);
    
        % Find sample index closest to the detected saccade time
        [~, eventIdx] = min(abs(timebase - detectedSaccadeTimes(k)));
    
        % Create window around the saccade
        idxRange = eventIdx - nBefore : eventIdx + nAfter;
    
        if idxRange(1) < 1 || idxRange(end) > length(EOGSignal)
            continue
        end
    
        % Extract trial
        trialWave = EOGSignal(idxRange);
        trialWave = trialWave(:);
    
        % Baseline-subtract each trial
        baselineWindow = round(0.10 * fsEstimate);
        baseline = mean(trialWave(nBefore-baselineWindow+1:nBefore));
        trialWave = trialWave - baseline;
    
        % Sort trial into correct group
        if prevCmd == 0 && thisCmd == -1
            trialsByType.centerToLeft(:,end+1) = trialWave;
    
        elseif prevCmd == -1 && thisCmd == 0
            trialsByType.leftToCenter(:,end+1) = trialWave;
    
        elseif prevCmd == 0 && thisCmd == 1
            trialsByType.centerToRight(:,end+1) = trialWave;
    
        elseif prevCmd == 1 && thisCmd == 0
            trialsByType.rightToCenter(:,end+1) = trialWave;
        end
    end
    
    % Average the trials in each group
    meanByType.centerToLeft = safeMean(trialsByType.centerToLeft);
    meanByType.leftToCenter = safeMean(trialsByType.leftToCenter);
    meanByType.centerToRight = safeMean(trialsByType.centerToRight);
    meanByType.rightToCenter = safeMean(trialsByType.rightToCenter);
    end
    
    function m = safeMean(trials)
    if isempty(trials)
        m = nan;
    else
        m = mean(trials, 2, 'omitnan');
    end
end
