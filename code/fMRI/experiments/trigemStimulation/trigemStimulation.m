
% Housekeeping
clear variables
close all
clc
rng(cputime); % Get some random going in case we need it

% Simulation flags
simulateCombiAir = true;
simulatePupilVideo = true;

% Define some acquisition properties
trialDurSecs = 4.5;
experimentStartKey = {'t'};
trDurSecs = 2.866;
nEPINoiseVolumes = 2;

% Video recording properties
pupilVidStartDelaySec = 20;
pupilVidStopDelaySec = 4;

% Define a sequence of pressure levels. This is a concatenated set of 4,
% deBruijn sequences each with first-order counter-balance. The labels have
% been arranged such that the sequence always starts with a blank (index 0)
% trial. An additional blank trial has been added to the start and end of
% each sequence. The second two sequences are a temporal reversal of the
% first two sequences. This structure supports unique identification of the
% HRF delay in model fitting.
stimIdxSeq = [0,0,8,8,6,7,5,2,5,3,3,9,6,6,9,5,10,7,1,0,2,3,4,3,6,8,7,10,9,3,2,9,8,2,6,4,5,1,2,7,3,7,4,6,1,7,2,10,5,8,10,0,7,9,1,6,2,4,1,4,7,6,3,1,1,10,10,2,8,0,9,4,4,2,0,3,0,6,5,4,10,6,10,4,9,9,2,2,1,5,9,10,1,8,1,3,5,6,0,4,8,9,0,1,9,7,8,3,10,8,4,0,5,5,7,7,0,10,3,8,5,0,0];

% Define the log-spaced pressure levels in PSI units
stimPressuresPSI = [0, 0.5000, 0.7937, 1.2599, 2.0000, 3.1748, 5.0397, 8.0000, 12.6992, 20.1587, 32.0000];

% Define the duration of the air puffs
stimDursMs = repmat(250,size(stimPressuresPSI));

% Set the test puff pressure to the middle of the pressure range
testPressurePSI = 5;

% Calculate the scan duration properties
nTrials = length(stimIdxSeq);
nTRs = ceil((nTrials * trialDurSecs)/trDurSecs) + nEPINoiseVolumes;
totalAcqDurSecs = nTRs * trDurSecs;

% Calculate the length of pupil recording needed.
pupilRecordingTime = ...
    pupilVidStartDelaySec + ...
    totalAcqDurSecs;

% Report the expected real reps:
fMRIDur = seconds(totalAcqDurSecs);
fMRIDur.Format = 'mm:ss';

textString = ['\tAssuming a TR of %2.3f ms, and %d EPI noise volumes,\n\tthe acqusition should have %d real reps,\n\tand a total duration of ' char(fMRIDur) ' (not including dummy scans)\n'];
fprintf('\n************************************************************************\n\n');
fprintf(textString,trDurSecs,nEPINoiseVolumes,nTRs)
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
    airObj.sendPressures(stimPressuresPSI);
    airObj.sendTrialDur(trialDurSecs);

    % Define the pressure we will use for initial puff testing
    airObj.setPressureDirect(testPressurePSI)
end

% Set up the pupil recording
if ~simulatePupilVideo
    pupilObj = PupilLabsControl(fullfile(resultDir,'rawPupilVideos'),...
        'filePrefix','',...
        'trialDurationSecs',pupilRecordingTime,...
        'backgroundRecording',true);
end

% Enter test mode, during which we can deliver puffs and attempt to clear
% the piston
notDone = true;
fprintf('\n');
while notDone
    fprintf('\nTest mode: p = puff, c = clear piston, q = quit...');
    keyPress = input(': ','s');
    switch keyPress
        case 'c'
            fprintf('Clearing the piston\n');
            if ~simulateCombiAir
                airObj.clearPistonDirect();
                pause(4);
            end
        case 'p'
            fprintf('Puff\n');
            if ~simulateCombiAir
                airObj.triggerPuffDirect();
                pause(4);
            end
        case 'q'
            notDone = false;
        otherwise
            fprintf('Invalid choice\n');
    end
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

    % We alternate between playing the stimulus sequence forwards and
    % backwards
    if mod((acqIdx-1),2)
        thisSequence = stimIdxSeq;
    else
        thisSequence = fliplr(stimIdxSeq);
    end

    if ~simulateCombiAir
        % Send this sequence to the combiAir
        airObj.sendSequence(thisSequence);

        % Put the combiAir in run mode. This ensures that the pending
        % stimulus pressure is set to the first trial of the sequence, so
        % we are ready to start.
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
    results.stimIdxSeq = thisSequence;
    results.stimDursMs = stimDursMs;
    results.stimPressuresPSI = stimPressuresPSI;
    results.trialDurSecs = trialDurSecs;
    results.trDurSecs = trDurSecs;
    results.nEPINoiseScans = nEPINoiseVolumes;

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

