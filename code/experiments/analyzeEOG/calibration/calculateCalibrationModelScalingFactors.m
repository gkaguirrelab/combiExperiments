%% calculateCalibrationModelScalingFactors.m

% SETUP
% Defining the directory
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir = 'FLIC_data';
projectName = 'combiLED';
EOGCalibrationDir = 'EOGCalibration';

% Define subjects + parameters
%
% Control subject IDs: {'FLIC_0013', 'FLIC_0015', 'FLIC_0017', ...
% 'FLIC_0018', 'FLIC_0019','FLIC_0020', 'FLIC_0021', 'FLIC_0022', 'FLIC_0027', 
% 'FLIC_0028','FLIC_0039', 'FLIC_0042'};
%
% Migraine subject IDs: {'FLIC_1016','FLIC_1029','FLIC_1030','FLIC_1031','FLIC_1032', ...
%        'FLIC_1034','FLIC_1035','FLIC_1036','FLIC_1038', 'FLIC_1041', 'FLIC_1044'};  
% 
% Had to take out 'FLIC_0028' for controls bc haven't done the fitting with her
subjectID = {'FLIC_0013', 'FLIC_0015', 'FLIC_0017', ...
'FLIC_0018', 'FLIC_0019','FLIC_0020', 'FLIC_0021', 'FLIC_0022', 'FLIC_0027',... 
'FLIC_0028','FLIC_0039', 'FLIC_0042'};     
nSubj = length(subjectID);
nSessions = 4;

% Initialize matrix of beta parameters
betaMatrix = zeros(nSubj,nSessions); 

% Initialize matrix of volts/degree parameters
voltsPerDegMatrix = zeros(nSubj,nSessions);

% Calibration target geometryS
degreesOfSaccade = 27.5 / 2;

% Extract timing of "left" "right" "center" commands from audio file
% This is the same for all subjects
audioFile = 'EOGCalInstructions.mp3';
onsets = extractCommandOnsets(audioFile); 

%% Determine the beta value for each EOG calibration for each subj

for subjIdx = 1:nSubj

    thisSubj = subjectID{subjIdx};

    for sessionIdx = 1:nSessions

        % Build path to the data file
        subjectDir = fullfile(dropBoxBaseDir, dropBoxSubDir, projectName, thisSubj);
        dataDir = fullfile(subjectDir, EOGCalibrationDir);

        fileName = fullfile(dataDir, ['EOGSession' num2str(sessionIdx) 'Cal.mat']);
        sessionData = load(fileName).sessionData;    

        % Parameters & timing
        fs = sessionData.Fs; % sampling rate is 48000 Hz
        fc = 0.12;                  % Filter cut-off frequency (Hz)
        timebase = sessionData.EOGData.timebase;
        Neog = length(timebase);
        cmdValues  = repmat([0 -1 0 1], 1, 3);  % 12 commands (center, left, center, right repeated 3x)
        nCmd = length(cmdValues);
        reactionTime = 0.5; % reaction time in seconds

        % Generate the model
        [x, y] = generateEOGModel(timebase, onsets, cmdValues, reactionTime, fc);

        % Grab the EOG signal from the data
        EOGSignal = sessionData.EOGData.response(1,:);

        % Force column vectors
        y = y(:);
        EOGSignal = EOGSignal(:);

        % Least-squares estimate of scale factor
        beta = y \ EOGSignal;

        % Scaled model
        y_scaled = beta * y;

        % Put this beta value into the beta matrix
        betaMatrix(subjIdx, sessionIdx) = beta;

        % Convert the values in the matrix to volts (amplitude) per degree of visual angle
        voltsPerDegMatrix(subjIdx, sessionIdx) = beta / degreesOfSaccade;

        clear sessionData
        clear beta

    end
end

%% Display results 
% (row = participant; col = calibration session)

% Each beta value in this matrix represents how much to scale the model to
% match the recorded EOG for that session. 
disp('Beta values:')
disp(betaMatrix)

% Each value in this matrix represents the approximate volts of EOG signal 
% per degree of eye movement for each session according to the model fit.
disp('Volts/degree visual angle:')
disp(voltsPerDegMatrix)

% Compute the mean volts/degree for each subject across the 4 calibration
% sessions. It is important to keep in mind that EOG  signal is quite 
% variable from session to session because the electrode placement isn't 
% always the same. One overall calibration estimate per subject is
% not exactly reliable. 
meanVoltsPerDeg = mean(voltsPerDegMatrix, 2);

% Compute the standard deviation of volts/degree across sessions for each
% subject. This tells us how stable the calibration estimate is across the
% 4 sessions.
stdVoltsPerDeg = std(voltsPerDegMatrix, 0, 2);

disp('Mean volts/degree for each subject across sessions:')
disp(meanVoltsPerDeg)

disp('Standard deviation of volts/degree across sessions for each subject:')
disp(stdVoltsPerDeg)

% TABLE (MEAN & STD)
calibrationSummaryTable = table(subjectID(:), meanVoltsPerDeg, stdVoltsPerDeg, ...
    'VariableNames', {'SubjectID', 'MeanVoltsPerDeg', 'StdAcrossSessions'});

disp('Subject-level calibration summary:')
disp(calibrationSummaryTable)


%%
function [x, y] = generateEOGModel(timebase, onsets, cmdValues, reactionTime, fc)
    % Initialize target square wave vector
    Neog = length(timebase);
    nCmd = length(cmdValues);
    x = zeros(Neog,1);
    for k = 1:nCmd
        if k < nCmd
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

function onsets = extractCommandOnsets(audioFile)
    [y, fs] = audioread(audioFile);
    
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
end