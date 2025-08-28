function presentTrialSequence(obj,sequence)

% Get the puffPSISet and the puffDurSecs
puffPSISet = obj.puffPSISet;
puffDurSecsSet = obj.puffDurSecsSet;

% Get the current trial index
currSequenceIdx = obj.sequenceIdx;

% Determine if we are simulating the stimuli
simulateStimuli = obj.simulateStimuli;

% The calling function sets the inter-trial interval range that occurs at
% the start of the trial
preStimDelayRangeSecs = obj.preStimDelayRangeSecs;

% Get the duration of the trial from the moment of puff onset
trialDurSecs = obj.trialDurSecs;

% Prepare the sounds
Fs = 8192; % Sampling Frequency
dur = 0.25; % Duration in seconds
t  = linspace(0, dur, round(Fs*dur));
lowTone = sin(2*pi*500*t);
audioObjs.low = audioplayer(lowTone,Fs);

% Prepare a vector to hold timing information for each trial
dateTimeVector = NaT(1,length(sequence));
itiVector = nan(1,length(sequence));

% Loop over the elements of the sequence
for tt = 1:length(sequence)

    % Get the next stimulus
    stimIdx = sequence(tt);
    puffPSI = puffPSISet(stimIdx);
    puffDurSecs = puffDurSecsSet(stimIdx);
    preStimDelaySecs = min(preStimDelayRangeSecs) + rand()*range(preStimDelayRangeSecs);

    % Store the variable itiVector
    itiVector(tt) = preStimDelaySecs;

    % Check that the max required pressure is within the safety range
    if puffPSI > obj.maxAllowedPressurePSI
        error('Requested puff pressure exceeds the safety limit');
    end

    % Check that the PSI * stimulus duration is not greater than
    % maxAllowedRefPSIPerSec
    if puffPSI*puffDurSecs > obj.maxAllowedRefPSIPerSec
        error('The PSI * duration of the stimulus exceeds the safety limit');
    end

    % Create the trial label
    trialLabel = [obj.trialLabelStem sprintf('_trial-%02d',tt)];

    % Handle verbosity
    if obj.verbose
        fprintf([trialLabel ': puff PSI [%2.2f] duration secs [%2.2f]...'],puffPSI,puffDurSecs);
    end

    % If not simulating
    if ~simulateStimuli

        % Alert the subject
        audioObjs.low.play;

        % Get the ir camera ready to record. We record for a period of time
        % before the stimulus equal to the minimum of the
        % preStimDelayRange, an we stop recording one second before the end
        % of the trial to allow time for the camera operations to complete
        % before the next trial.
        obj.irCameraObj.durationSecs = min(preStimDelayRangeSecs)+trialDurSecs-obj.cameraCleanupDurSecs;
        obj.irCameraObj.prepareToRecord(trialLabel);

        % Set the puff durations
        obj.AirPuffObj.setDuration('L',puffDurSecs*1000);
        obj.AirPuffObj.setDuration('R',puffDurSecs*1000);

        % Set the puff pressures
        obj.AirPuffObj.setPressure('L',puffPSI);
        obj.AirPuffObj.setPressure('R',puffPSI);

        % Pause briefly before we start the video recording. This ensures
        % that the video start time has the same timing across trials with
        % respect to the air puff
        stopTimeSeconds = cputime() + preStimDelaySecs - min(preStimDelayRangeSecs);
        obj.waitUntil(stopTimeSeconds);

        % Define a stop time that is at the end of the pre stimulus delay.
        stopTimeSeconds = cputime() + min(preStimDelayRangeSecs);

        % Store the start time of the trial
        dateTimeVector(tt) = datetime('now','Format','yyyy-MM-dd HH:mm:ss.SSSSSS');

        % Start the ir camera recording
        obj.irCameraObj.startRecording(trialLabel);

        % Wait until the pre stim delay has ended
        obj.waitUntil(stopTimeSeconds);

        % Define the stop time for the trial.
        stopTimeSeconds = cputime() + trialDurSecs;

        % Simultaneous, bilateral puff
        obj.AirPuffObj.triggerPuff('ALL');

        % Wait until the video recording file has closed
        obj.irCameraObj.checkFileClosed;

        % Wait until the trial has ended
        obj.waitUntil(stopTimeSeconds);

    end

    % Finish the line of text output
    if obj.verbose
        fprintf('done\n');
    end

end

% Get the trialData from the obj
trialData = obj.trialData;

% Add in the stimulus information
trialData(currSequenceIdx).dateTimeVector = dateTimeVector;
trialData(currSequenceIdx).itiVector = itiVector;
trialData(currSequenceIdx).puffPSISet = puffPSISet;
trialData(currSequenceIdx).puffDurSecsSet = puffDurSecsSet;
trialData(currSequenceIdx).sequence = sequence;

% Put trialData back into the obj
obj.trialData = trialData;

% Increment the trial index
obj.sequenceIdx = currSequenceIdx+1;

end