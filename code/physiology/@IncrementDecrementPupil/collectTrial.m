function collectTrial(obj)

% Determine if we are simulating the stimuli and/or the recording
simulateStimuli = obj.simulateStimuli;
simulateRecording = obj.simulateRecording;

% Get the time we started
startTime = datetime();

% Get the stimulus contrast
stimContrast = obj.stimContrast;

% Prepare the sounds
Fs = 8192; % Sampling Frequency
dur = 0.1; % Duration in seconds
t  = linspace(0, dur, round(Fs*dur));
lowTone = sin(2*pi*500*t);
midTone = sin(2*pi*750*t);
highTone = sin(2*pi*1000*t);
readySound = [lowTone midTone highTone];
audioObjs.ready = audioplayer(readySound,Fs);
audioObjs.finished = audioplayer(fliplr(readySound),Fs);

% Handle verbosity
if obj.verbose
    fprintf('Contrast %2.2f: ', stimContrast);
end

% Update the file prefix for the pupil object
filePrefix = sprintf('trial_%02d_',obj.trialIdx);
obj.pupilObj.filePrefix = filePrefix;
obj.pupilObj.trialIdx = obj.trialIdx;

% Present the stimuli
if ~simulateStimuli

    % Configure the contrast and phase (and thus increment or decrement)
    obj.CombiLEDObj.setContrast(abs(stimContrast));
    obj.CombiLEDObj.setPhaseOffset((sign(stimContrast)<0)*pi);

    % Jittered inter trial interval
    jitterTimeSecs = (rand*range(obj.preTrialJitterRangeSecs) + min(obj.preTrialJitterRangeSecs));
    obj.waitMilliseconds(jitterTimeSecs*1e3);

    % Figure out when we anticipate that the video recording will be ready
    % to go
    stopTime = datetime() + seconds(obj.pupilVidStartDelaySec);

    % Start the video recoding
    if ~simulateRecording
        obj.pupilObj.recordTrial;
    end

    % Alert the subject the trial is about to start
    audioObjs.ready.play;

    % Finish waiting for pupil recording to have started
    obj.waitUntil(stopTime);

    % Calculate the stop time for the recording
    stopTime = datetime() + seconds(obj.pulseDurSecs + obj.postPulseRecordingDurSecs);

    % Start the stimulus
    obj.CombiLEDObj.startModulation;

    % Wait for the trial duration
    obj.waitUntil(stopTime);

    % Store the trial data, starting with a measure of how long it
    % started the video recording to start
    vidDelaySecs = nan;
    if ~simulateRecording
        while isnan(vidDelaySecs)
            vidDelaySecs = obj.pupilObj.calcVidDelay(obj.trialIdx);
        end
    end
    obj.trialData(obj.trialIdx).vidDelaySecs = vidDelaySecs;

    % Store the stimulus properties
    obj.trialData(obj.trialIdx).jitterTimeSecs = jitterTimeSecs;
    obj.trialData(obj.trialIdx).stimContrast = stimContrast;

    % Play the finished tone
    audioObjs.finished.play;
    obj.waitUntil(datetime() + seconds(1));

end

% Store the startTime
obj.trialData(obj.trialIdx).startTime = startTime;

% Iterate the trialIdx
obj.trialIdx = obj.trialIdx+1;

% Finish the line of text output
if obj.verbose
    fprintf('\n');
end

end