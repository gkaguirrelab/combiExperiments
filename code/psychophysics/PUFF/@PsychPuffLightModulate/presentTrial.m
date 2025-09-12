function presentTrial(obj)

% Get the current trial index
currTrialIdx = size(obj.trialData,1)+1;

% Determine if we are simulating the stimuli
simulateStimuli = obj.simulateStimuli;
simulateResponse = obj.simulateResponse;

% Prepare the sounds
Fs = 8192; % Sampling Frequency
dur = 0.1; % Duration in seconds
t  = linspace(0, dur, round(Fs*dur));
lowTone = sin(2*pi*500*t);
midTone = sin(2*pi*750*t);
highTone = sin(2*pi*1000*t);
readySound = [lowTone midTone highTone];
correctSound = sin(2*pi*750*t);
incorrectSound = sin(2*pi*250*t);
badSound = [sin(2*pi*250*t) sin(2*pi*250*t)];
audioObjs.low = audioplayer(lowTone,Fs);
audioObjs.mid = audioplayer(midTone,Fs);
audioObjs.high = audioplayer(highTone,Fs);
audioObjs.ready = audioplayer(readySound,Fs);
audioObjs.correct = audioplayer(correctSound,Fs);
audioObjs.incorrect = audioplayer(incorrectSound,Fs);
audioObjs.bad = audioplayer(badSound,Fs);

% Handle verbosity
if obj.verbose
    fprintf(['Trial %d; phase %2.1f, ' obj.trialLabel '...'], ...
        currTrialIdx,obj.lightModPhase);
end

% Prepare some items for the trialData recod
trialStartTime = datetime();
irVidTrialLabel = [];

% Present the stimuli
if ~simulateStimuli

    % Set the phase for this modulation
    obj.LightObj.phaseOffset(obj.lightModPhase);

    % Play the ready sound
    audioObjs.mid.play

    % Define a camera recording time, which includes:
    % - 1 second before the light modulation starts
    % - the duration of the light modulation
    % - 1 second after the light modulation ends
    camRecordTimeSecs = 1 + obj.lightModDurSecs + 1;

    % Define an overall minimum end time for the trial, which is the camera
    % record time plus the camera clean up time
    totalTrialTime = camRecordTimeSecs + obj.cameraCleanupDurSecs;
    overallStopTimeSecs = cputime() + totalTrialTime;

    % Start the camera recording
    obj.irCameraObj.durationSecs = camRecordTimeSecs;
    irVidTrialLabel = sprintf([obj.trialLabel '_trial-%03d'],currTrialIdx);
    obj.irCameraObj.prepareToRecord(irVidTrialLabel);
    obj.irCameraObj.startRecording(irVidTrialLabel);

    % We let the IR camera start recording for a second before the light
    % starts. This way we can measure the pupil response to the stimulus,
    % and give a moment for the updated combiLED settings to be passed.
    stopTimeSeconds = cputime() + 1;
    obj.waitUntil(stopTimeSeconds);

    % Start the light modulation
    obj.LightObj.startModulation;

    % Wait until the light modulation has ended
    stopTimeSeconds = cputime() + obj.lightModDurSecs;
    obj.waitUntil(stopTimeSeconds);

    % Make sure the modulation has stopped
    obj.LightObj.stopModulation;
    
    % Play the end tone
    audioObjs.low.play;

    % Wait until the camera has cleaned up and closed
    obj.irCameraObj.checkFileClosed;
    obj.waitUntil(overallStopTimeSecs);

end

% Finish the line of text output
if obj.verbose
    fprintf('done\n');
end

% Add in the stimulus information
trialData = obj.trialData;
trialData(currTrialIdx).trialStartTime = trialStartTime;
trialData(currTrialIdx).irVidTrialLabel = irVidTrialLabel;
trialData(currTrialIdx).lightModPhase = obj.lightModPhase;

% Put questData back into the obj
obj.trialData = trialData;

end