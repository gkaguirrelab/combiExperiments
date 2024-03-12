
% Housekeeping
clear variables
close all
clc
rng(cputime); % Get some random going in case we need it

% Simulation flags
simulateCombiAir = false;
simulatePupilVideo = false;

% Define some acquisition properties
nTrials = 129;
trialDurSecs = 4.5;
totalAcqDurSecs = nTrials * trialDurSecs;
experimentStartKey = {'t'};
trDurSecs = 2.040;

% Video recording properties
pupilVidStartDelaySec = 20;
pupilVidStopDelaySec = 4;

% Calculate the length of pupil recording needed.
pupilRecordingTime = ...
    pupilVidStartDelaySec + ...
    totalAcqDurSecs;

% Report the expected real reps:
fMRIDur = seconds(ceil(totalAcqDurSecs/trDurSecs)*trDurSecs);
fMRIDur.Format = 'mm:ss';

textString = ['Assuming a TR of %2.3f ms, the acqusition should have %d real reps, and a total duration of ' char(fMRIDur) ' (not including dummy scans)\n'];
fprintf('\n************************************\n\n');
fprintf(textString,trDurSecs,ceil(totalAcqDurSecs/trDurSecs))
fprintf('\n************************************\n');

% Get observer properties
observerID = GetWithDefault('Subject ID','xxxx');

% The name of the directory in which to store the results files
dropboxBaseDir = getpref('combiExperiments','dropboxBaseDir');
sessionID = string(datetime('now','Format','yyyy-MM-dd'));

% Create the directory in which to save the data
resultDir = fullfile(dropboxBaseDir,'MELA_data','combiAir','trigemFiveLevel',observerID,sessionID);
if ~isfolder(resultDir)
    mkdir(resultDir)
end

% Set up the combiAir
if ~simulateCombiAir
    airObj = CombiAirControl();
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
        airObj.startModulation;
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
        airObj.stopModulation;
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

