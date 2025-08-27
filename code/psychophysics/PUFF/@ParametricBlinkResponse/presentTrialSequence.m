function presentTrialSequence(obj,trialLabel,puffPSI,puffDurSecs)

% Get the current trial index
currTrialIdx = obj.currTrialIdx;

% Determine if we are simulating the stimuli
simulateStimuli = obj.simulateStimuli;

% The calling function sets the inter-trial interval range that occurs at
% the start of the trial
preStimDelayRangeSecs = obj.preStimDelayRangeSecs;

% Get the duration of the trial from the moment of puff onset
trialDurSecs = obj.trialDurSecs;

% Check that the max required pressure is within the safety range
if puffPSI > obj.maxAllowedPressurePSI
    error('Requested puff pressure exceeds the safety limit');
end

% Check that the PSI * stimulus duration is not greater than
% maxAllowedRefPSIPerSec
if puffPSI*puffDurSecs > obj.maxAllowedRefPSIPerSec
    error('The PSI * duration of the stimulus exceeds the safety limit');
end

% Prepare the sounds
Fs = 8192; % Sampling Frequency
dur = 0.1; % Duration in seconds
t  = linspace(0, dur, round(Fs*dur));
lowTone = sin(2*pi*500*t);
audioObjs.low = audioplayer(lowTone,Fs);

% Handle verbosity
if obj.verbose
    fprintf(['Trial ' trialLabel '; puff PSI [%2.2f] duration secs [%2.2f]...'],puffPSI,puffDurSecs);
end

% Set the preStimDelaySecs
preStimDelaySecs = min(preStimDelayRangeSecs) + rand()*range(preStimDelayRangeSecs);

% Present the stimuli
if ~simulateStimuli

    % Get the ir camera ready to record
    obj.irCameraObj.durationSecs = min(preStimDelayRangeSecs)+trialDurSecs;
    obj.irCameraObj.prepareToRecord(trialLabel);

    % Set the puff durations
    obj.AirPuffObj.setDuration('L',puffDurSecs*1000);
    obj.AirPuffObj.setDuration('R',puffDurSecs*1000);

    % Set the puff pressures
    obj.AirPuffObj.setPressure('L',puffPSI);
    obj.AirPuffObj.setPressure('R',puffPSI);

    % Define a stop time that is at the end of the pre stimulus delay.
    stopTimeSeconds = cputime() + preStimDelaySecs;
    
    % Alert the subject
    audioObjs.low.play;

    % Pause briefly before we start the video recording. This ensures that
    % the video start time has the same timing across trials with respect
    % to the air puff
    pause(preStimDelaySecs - min(preStimDelayRangeSecs));

    % Start the ir camera recording
    obj.irCameraObj.startRecording(trialLabel);

    % Wait until the pre stim delay has ended
    obj.waitUntil(stopTimeSeconds);

    % Define the stop time for the trial.
    stopTimeSeconds = cputime() + trialDurSecs;

    % Simultaneous, bilateral puff
    obj.AirPuffObj.triggerPuff('ALL');

    % Wait until the trial has ended
    obj.waitUntil(stopTimeSeconds);
    
end

% Finish the line of text output
if obj.verbose
    fprintf('done\n');
end

% Get the trialData from the obj
trialData = obj.trialData;

% Add in the stimulus information
trialData(currTrialIdx).datetime = datetime('now','Format','yyyy-MM-dd HH:mm:ss.SSSSSS');
trialData(currTrialIdx).trialLabel = trialLabel;
trialData(currTrialIdx).puffPSI = puffPSI;
trialData(currTrialIdx).puffDurSecs = puffDurSecs;
trialData(currTrialIdx).preStimDelaySecs = preStimDelaySecs;

% Put trialData back into the obj
obj.trialData = trialData;

% Increment the trial index
obj.currTrialIdx = currTrialIdx+1;

end