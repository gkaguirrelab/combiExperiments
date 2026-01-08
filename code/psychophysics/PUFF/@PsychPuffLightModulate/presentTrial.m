function presentTrial(obj)

% Get the current trial index
currTrialIdx = size(obj.trialData,2)+1;

% Determine if we are simulating the stimuli
simulateStimuli = obj.simulateStimuli;
simulateResponse = obj.simulateResponse;

% Prepare the sounds
Fs = 8192; % Sampling Frequency
dur = 0.25; % Duration in seconds
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
blinkTimeSecs = []; detected = []; responseTimeSecs = [];

% Present the stimuli
if ~simulateStimuli

    % Update the combiLED modulation direction, contrast, and phase offset,
    % in case these have changed from the last call
    obj.LightObj.setSettings(obj.modResult);
    obj.LightObj.setContrast(obj.lightModContrast);    
    obj.LightObj.setPhaseOffset(obj.lightModPhase);

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

    % Play the ready sound
    Speak('go');

    % Start the light modulation
    obj.LightObj.startModulation;

    % Store the start time
    startTimeSecs = cputime();

    % Define the stop time for the end of the blink detection period.
    stopTimeSeconds = startTimeSecs + obj.lightModDurSecs ...
        - obj.blinkEventIntervalSecs - obj.blinkResponseIntervalSecs - 4;

    % Pause two seconds so that there is no blink event at the immediate
    % start of the light pulse
    pause(2);

    % Enter a while loop that presents occasional blink events for the
    % subject to detect. This continues until we reach the end of the light
    % pulse
    blinkCounter = 1;
    while cputime() < stopTimeSeconds

        % Define when this interval is over
        thisInteralStopTimeSecs = cputime()+ obj.blinkEventIntervalSecs;

        % probability of having a blink event in this interval
        if rand() < obj.blinkEventProbability

            % The timing of the event is uniformly distributed within the
            % interval
            pauseDurSecs = obj.blinkEventIntervalSecs * rand();
            pause(pauseDurSecs);

            % Store the blink time relative to the start of the light pulse
            blinkTimeSecs(blinkCounter) = cputime() - startTimeSecs;

            % Present the blink event
            obj.LightObj.blink;

            % See if the observer responds
            if ~simulateResponse
                [detected(blinkCounter), responseTimeSecs(blinkCounter)] = obj.blinkEvent;
                if detected(blinkCounter)
                    audioObjs.correct.play
                else
                    audioObjs.incorrect.play
                end
            else
                detected(blinkCounter) = nan;
                responseTimeSecs(blinkCounter) = nan;
            end

            % Increment the blink counter
            blinkCounter = blinkCounter +1;
        end

        % Wait for this interval
        obj.waitUntil(thisInteralStopTimeSecs);

    end

    % Wait until the camera has cleaned up and closed
    obj.irCameraObj.checkFileClosed;
    obj.waitUntil(overallStopTimeSecs);

    % Make sure the modulation has stopped
    obj.LightObj.stopModulation;
    
    % Play the end tone
    audioObjs.mid.play;

end

% Finish the line of text output
if obj.verbose
    fprintf('done\n');
end

% Update the trial data
trialData = obj.trialData;

% Add in the trial information
trialData(currTrialIdx).trialStartTime = trialStartTime;
trialData(currTrialIdx).lightModPhase = obj.lightModPhase;
trialData(currTrialIdx).irVidTrialLabel = irVidTrialLabel;
trialData(currTrialIdx).blinkTimeSecs = blinkTimeSecs;
trialData(currTrialIdx).detected = detected;
trialData(currTrialIdx).responseTimeSecs = responseTimeSecs;

% Put questData back into the obj
obj.trialData = trialData;

end