function presentTrial(obj)

% Get the questData
questData = obj.questData;

% Get the current trial index
currTrialIdx = size(questData.trialData,1)+1;

% Determine if we are simulating the stimuli
simulateStimuli = obj.simulateStimuli;
simulateResponse = obj.simulateResponse;

% Determine if we are giving feedback on each trial
giveFeedback = obj.giveFeedback;

% The calling function sets the refPuffPSI, the duration of each puff, and
% the inter-trial interval range
refPuffPSI = obj.refPuffPSI;
puffDurSecs = obj.puffDurSecs;

% Get the stimParam to use for this trial.
testParam = qpQuery(questData);

% The difference between the reference and test frequency is given by the
% testParam, which is in units of decibels.
testPuffPSI = refPuffPSI * db2pow(testParam);

% If the testPuffPSI is great than the maximum allowed PSI value, adjust
% the stimParam to stay within the max allowed
if testPuffPSI > obj.maxAllowedPressurePSI
    maxStimParam = pow2db(obj.maxAllowedPressurePSI / refPuffPSI);
    [~,idx]=find(obj.stimParamsDomainList<maxStimParam,1,"last");
    testParam = obj.stimParamsDomainList(idx);
    testPuffPSI = refPuffPSI * db2pow(testParam);
    warning('test param reduced to be within allowed safety range');
end

% Assemble the param sets
testParams = [testPuffPSI,puffDurSecs];
refParams = [refPuffPSI,puffDurSecs];

% Randomly assign the stimuli the first or second interval
switch 1+logical(round(rand()))
    case 1
        intervalParams(1,:) = testParams;
        intervalParams(2,:) = refParams;
        testInterval = 1;
    case 2
        intervalParams(1,:) = refParams;
        intervalParams(2,:) = testParams;
        testInterval = 2;
    otherwise
        error('Not a valid interval')
end

% Note which interval contains the more intense stimulus, which is used for
% feedback
[~,moreIntenseInterval] = max(intervalParams(:,1));

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
    fprintf(['Trial %d; Waveform ' obj.lightPulseWaveform ' Pulse contrast [%2.2f]; Puff duration [%2.2f]; Pressure PSI [%2.2f, %2.2f PSI]...'], ...
        currTrialIdx,obj.lightPulseModContrast,obj.puffDurSecs,intervalParams(1,1),intervalParams(2,1));
end

% Present the stimuli
if ~simulateStimuli

    % Play the ready sound
    audioObjs.ready.play

    % Set the puff durations for the first interval
    obj.AirPuffObj.setDuration('L',obj.puffDurSecs*1000);
    obj.AirPuffObj.setDuration('R',obj.puffDurSecs*1000);

    % Set the puff pressures for the first interval
    obj.AirPuffObj.setPressure('L',intervalParams(1,1));
    obj.AirPuffObj.setPressure('R',intervalParams(1,1));

    % Define a camera recording time, which includes:
    % - 1 second before the light pulse
    % - light pulse, isi, light pulse
    % - 1 second after the second light pulse and air puff
    camRecordTimeSecs = 1 + obj.lightPulseDurSecs + obj.isiSecs + obj.lightPulseDurSecs + 1;

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

    % Set the stimulus contrast / phase for the first interval
    switch obj.lightPulseWaveform
        case 'background'
            obj.LightObj.setContrast(0);
            pause(0.1);
            obj.LightObj.setPhaseOffset(0);
        case 'high-low'
            obj.LightObj.setContrast(obj.lightPulseModContrast);
            pause(0.1);
            obj.LightObj.setPhaseOffset(pi);
        case 'low-high'
            obj.LightObj.setContrast(obj.lightPulseModContrast);
            pause(0.1);
            obj.LightObj.setPhaseOffset(0);
    end

    % Wait until the pre-light period has ended
    obj.waitUntil(stopTimeSeconds);

    % Define when the light pulse period ends
    stopTimeSeconds = cputime() + obj.lightPulseDurSecs;

    % Start the light pulse
    obj.LightObj.startModulation;

    % Wait until the light pulse has ended
    obj.waitUntil(stopTimeSeconds);

    % Play the first puff sound, and pause briefly to let it get started
    audioObjs.low.play;
    pause(0.1);

    % Simultaneous, bilateral puff
    obj.AirPuffObj.triggerPuff('ALL');

    % Define the duration of an ISI
    stopTimeSeconds = cputime() + obj.isiSecs;

    % Wait for the pulse to be over and serial port control to have
    % returned
    pause(obj.puffDurSecs+0.1);

    % Set the puff durations for the second interval
    obj.AirPuffObj.setDuration('L',obj.puffDurSecs*1000);
    obj.AirPuffObj.setDuration('R',obj.puffDurSecs*1000);

    % Set the puff pressures for the second interval
    obj.AirPuffObj.setPressure('L',intervalParams(2,1));
    obj.AirPuffObj.setPressure('R',intervalParams(2,1));

    % Prepare the light pulse for the second interval
    switch obj.lightPulseWaveform
        case 'background'
            obj.LightObj.setContrast(0);
            pause(0.1);
            obj.LightObj.setPhaseOffset(0);
        case 'high-low'
            obj.LightObj.setContrast(obj.lightPulseModContrast);
            pause(0.1);
            obj.LightObj.setPhaseOffset(0);
        case 'low-high'
            obj.LightObj.setContrast(obj.lightPulseModContrast);
            pause(0.1);
            obj.LightObj.setPhaseOffset(pi);
    end

    % Wait until the ISI has ended
    obj.waitUntil(stopTimeSeconds);

    % Define when the light pulse period ends
    stopTimeSeconds = cputime() + obj.lightPulseDurSecs;

    % Start the second light pulse
    obj.LightObj.startModulation;

    % Finish waiting out the second light pulse
    obj.waitUntil(stopTimeSeconds);

    % Play the second puff tone, and pause briefly to let it get started
    audioObjs.mid.play;
    pause(0.1);

    % Simultaneous, bilateral puff
    obj.AirPuffObj.triggerPuff('ALL');

end

% Re-express the testParam as the dB difference between the second and
% first interval; this is how we will think about the outcome
testParam = pow2db(intervalParams(2,1)/intervalParams(1,1));

% Start the response interval
if ~simulateResponse
    FlushEvents
    [intervalChoice, responseTimeSecs] = obj.getResponse();
else
    intervalChoice = obj.getSimulatedResponse(testParam);
    responseTimeSecs = nan;
end

% The outcome is simply the interval that has been selected
outcome = intervalChoice;

% Determine if the subject has selected the more intense interval and
% handle audio feedback. Make the correct noise regardless of the response
% when the two stimuli were identical.
if intervalChoice==moreIntenseInterval || testParam == 0
    % Correct
    correct = true;
    if obj.verbose
        fprintf('correct');
    end
    if ~simulateStimuli
        % We are not simulating, and the response was correct.
        % Regardless of whether we are giving feedback or not, we will
        % play the "correct" tone
        audioObjs.correct.play;
        obj.waitUntil(cputime()+1.0);
    end
else
    % incorrect
    correct = false;
    if obj.verbose
        fprintf('incorrect');
    end
    if ~simulateStimuli
        % We are not simulating
        if giveFeedback
            % We are giving feedback, so play the "incorrect" tone
            audioObjs.incorrect.play;
        else
            % We are not giving feedback, so play the same "correct"
            % tone that is played for correct responses
            audioObjs.mid.play;
        end
        obj.waitUntil(cputime()+1.0);
    end
end

% Wait until the total trial time has elapsed, or we have finished the
% minimum iti, whichever comes later. Also make sure that the recording has
% finished
if ~simulateStimuli

    % Define the stop time
    stopTimeSeconds = max([...
        overallStopTimeSecs, ...
        cputime() + obj.minItiSecs]);

    % Wait until the video recording file has closed
    obj.irCameraObj.checkFileClosed;

    % Keep waiting until we are done
    obj.waitUntil(stopTimeSeconds);

end

% Finish the line of text output
if obj.verbose
    fprintf('\n');
end

% Update questData
questData = qpUpdate(questData,testParam,outcome);

% Add in the stimulus information
questData.trialData(currTrialIdx).testParam = testParam;
questData.trialData(currTrialIdx).testInterval = testInterval;
questData.trialData(currTrialIdx).moreIntenseInterval = moreIntenseInterval;
questData.trialData(currTrialIdx).intervalChoice = intervalChoice;
questData.trialData(currTrialIdx).responseTimeSecs = responseTimeSecs;
questData.trialData(currTrialIdx).correct = correct;
questData.trialData(currTrialIdx).irVidTrialLabel = irVidTrialLabel;

% Put questData back into the obj
obj.questData = questData;

end