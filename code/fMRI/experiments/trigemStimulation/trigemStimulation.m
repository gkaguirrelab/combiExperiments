
% Housekeeping
clear variables
close all
clc
rng(cputime); % Get some random going in case we need it

% Simulation flags
simulateCombiAir = false;
simulatePupilVideo = true;

% Define some acquisition properties
trialDurSecs = 4.5;
experimentStartKey = {'t'};
trDurSecs = 2.866;
nEPINoiseScans = 2;

% Video recording properties
pupilVidStartDelaySec = 20;
pupilVidStopDelaySec = 4;

% Define a sequence of pressure levels. This is a concatenated set of 3,
% deBruijn sequences each with first-order counter-balance. An additional
% blank trial has been added to the start and end of the sequence.
stimIdxSeq = [0,0,3,3,4,0,2,0,4,4,2,1,4,3,1,0,1,3,2,4,1,1,2,2,3,0,0,2,2,3,4,3,0,1,4,2,0,4,1,2,1,3,3,2,4,4,0,3,1,1,0,0,2,0,4,2,4,4,1,3,3,4,0,3,0,1,1,4,3,1,2,3,2,2,1,0,0];

% Define the duration of the air puffs
stimDursMs = [500, 500, 500, 500, 500];

% Define three sets of log-spaced pressure levels in PSI units
stimPressuresPSI{1} = [0, 1.000, 2.573,  6.622, 17.041];
stimPressuresPSI{2} = [0, 1.370, 3.526,  9.075, 23.352];
stimPressuresPSI{3} = [0, 1.878, 4.832, 12.435, 32.000];

% Calculate the scan duration properties
nTrials = length(stimIdxSeq);
totalAcqDurSecs = (nTrials+nEPINoiseScans) * trialDurSecs;

% Calculate the length of pupil recording needed.
pupilRecordingTime = ...
    pupilVidStartDelaySec + ...
    totalAcqDurSecs;

% Report the expected real reps:
fMRIDur = seconds(ceil(totalAcqDurSecs/trDurSecs)*trDurSecs);
fMRIDur.Format = 'mm:ss';

textString = ['\tAssuming a TR of %2.3f ms, and %d EPI noise scans,\n\tthe acqusition should have %d real reps,\n\tand a total duration of ' char(fMRIDur) ' (not including dummy scans)\n'];
fprintf('\n************************************************************************\n\n');
fprintf(textString,trDurSecs,nEPINoiseScans,ceil(totalAcqDurSecs/trDurSecs))
fprintf('\n************************************************************************\n');

% Get observer properties
observerID = GetWithDefault('Subject ID','xxxx');

% The name of the directory in which to store the results files
dropboxBaseDir = getpref('combiExperiments','dropboxBaseDir');
sessionID = string(datetime('now','Format','yyyy-MM-dd'));

% Create the directory in which to save the data
resultDir = fullfile(dropboxBaseDir,'BLNK_data','combiAir','trigemFiveLevel',observerID,sessionID);
if ~isfolder(resultDir)
    mkdir(resultDir)
end

% Set up the combiAir
if ~simulateCombiAir
    % Create the object
    airObj = CombiAirControl();

    % Send the sequence properties to the combiAir
    airObj.sendSequence(stimIdxSeq);
    airObj.sendDurations(stimDursMs);
    airObj.sendPressures(stimPressuresPSI{1});
    airObj.sendTrialDur(trialDurSecs);
end

% Set up the pupil recording
if ~simulatePupilVideo
    pupilObj = PupilLabsControl(fullfile(resultDir,'rawPupilVideos'),...
        'filePrefix','',...
        'trialDurationSecs',pupilRecordingTime,...
        'backgroundRecording',true);
end

% Wait during the preliminary acquisitions and soak up any stray keystrokes
% (e.g., testing the button box; TRs produced by the field map acquisition)
fprintf('******************************************************\n')
fprintf('Press return when you are ready to start the fMRI scan\n')
fprintf(' (button presses and TRs will be ignored until then)  \n')
input(': ','s');
fprintf('******************************************************\n')

% Keep collecting acquisitions until we are done
notDone = true;
acqIdx = 1;

while notDone

    % Create an empty variable that will store information about this
    % acquisition
    results = [];

    % Identify which set of sequences we will use
    thisSet = mod(acqIdx-1,length(stimPressuresPSI))+1;

    if ~simulateCombiAir
        % Send this set of pressure levels to the combiAir
        airObj.sendPressures(stimPressuresPSI{thisSet});

        % Put the combiAir in run mode. This ensures that the pending stimulus
        % pressure is set to the first trial of the sequence, so we are ready
        % to start.
        airObj.setRunMode();
    end

    % Start the pupil recording
    if ~simulatePupilVideo
        videoStartTime = datetime();
        pupilObj.trialIdx = acqIdx;
        pupilObj.recordTrial;
    end

    % Create a keypress response window
    [currKeyPress,S] = createResponseWindow();

    % Wait for a "t" stimulus to start the acquisition
    fprintf('Waiting for a TR trigger...')
    getResponse(currKeyPress,Inf,experimentStartKey);

    % Get the start time
    acqStartTime = datetime();

    % Tell the combiAir to start the sequence
    if ~simulateCombiAir
        airObj.startSequence;
    end

    % Announce we are starting
    fprintf('starting\n')
    fprintf('Acquisition %d \n',acqIdx);

    % Wait while the experiment is ongoing
    while seconds(datetime() - acqStartTime) < totalAcqDurSecs
    end

    % Announce we are cleaning up
    fprintf('cleaning up...')
    if ~simulateCombiAir
        airObj.stopSequence;
    end
    pause(pupilVidStopDelaySec)

    % Measure how long it took the video to start
    if ~simulatePupilVideo
        % [vidDelaySecs, recordStartTime] = pupilObj.calcVidDelay(acqIdx);
        % results.vidDelaySecs = vidDelaySecs;
        % results.videoRecordCommandTime = videoStartTime;
        % results.videoRecordStartTime = recordStartTime;
    end

    % Add some acquisition-level information to the results
    results.observerID = observerID;
    results.acqStartTime = acqStartTime;
    results.totalAcqDurSecs = totalAcqDurSecs;
    results.stimIdxSeq = stimIdxSeq;
    results.stimDursMs = stimDursMs;
    results.stimPressuresPSI = stimPressuresPSI{thisSet};
    results.trialDurSecs = trialDurSecs;
    results.trDurSecs = trDurSecs;
    results.nEPINoiseScans = nEPINoiseScans;

    % Save the results file to disk
    filename = strrep(strrep([observerID sprintf('_%s.mat', datetime())],' ','_'),':','.');
    save(fullfile(resultDir,filename),'results');

    % Announce that we are done this acquisition
    fprintf('Finished acquisition.\nPress space to prepare for the next acquisition, or q to end...')
    keyPress = getResponse(currKeyPress,Inf,{'space','q'});
    switch keyPress
        case 'q'
            fprintf('\n')
            notDone = false;
        otherwise
            fprintf('preparing\n')
            acqIdx = acqIdx+1;
    end

    % Close the keypress window
    close(S.fh);

end

% Clean up combiAir
if ~simulateCombiAir; airObj.serialClose; end

