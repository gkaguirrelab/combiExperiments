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
itiRangeSecs = obj.itiRangeSecs;
itiDur = []; % Define this in case we are in simulate mode

% Get the stimParam to use for this trial.
testParam = qpQuery(questData);

% The difference between the reference and test frequency is given by the
% testParam, which is in units of decibels. The stimParamSide setting tells
% us if we are setting the test frequency higher or lower than the ref.
switch obj.stimParamSide
    case 'hi'
        testPuffPSI = refPuffPSI * db2pow(testParam);
    case 'low'
        testPuffPSI = refPuffPSI / db2pow(testParam);
    otherwise
        error('not a valid stimParamSide setting')
end

% If the testPuffPSI is great than the maximum allowed PSI value, adjust
% the stimParam to stay within the max allowed
if testPuffPSI > obj.maxAllowedPressurePSI
    maxStimParam = pow2db(obj.maxAllowedPressurePSI / refPuffPSI);
    [~,idx]=find(obj.stimParamsDomainList<maxStimParam,1,"last");
    testParam = obj.stimParamsDomainList(idx);
    testPuffPSI = refPuffPSI * db2pow(testParam);
    warning('test param reduced to be within allowed safety range');
end

if testParam == 0
    foo=1;
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

% Note which side contains the more intense stimulus, which is used for
% feedback
[~,moreIntenseInterval] = max(intervalParams(:,1));

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
    fprintf('Trial %d; Pulse contrast [%2.2f]; Puff duration [%2.2f]; Pressure PSI [%2.2f, %2.2f PSI]...', ...
        currTrialIdx,obj.lightPulseContrast,obj.puffDurSecs,intervalParams(1,1),intervalParams(2,1));
end

% Present the stimuli
if ~simulateStimuli

    % Define when the pre-puff period ends
    stopTimeSeconds = cputime() + obj.prePuffLightSecs;

    % Set the stimulus contrast and duration. These were set when the
    % object was initialized, but we re-set now just in case a different
    % object changed them
    obj.LightObj.setContrast(obj.lightPulseContrast);
    obj.LightObj.setDuration(obj.lightPulseDuration);
    
    % Start the light pulse
    obj.LightObj.startModulation;

    % Set the puff durations
    obj.AirPuffObj.setDuration('L',obj.puffDurSecs*1000);
    obj.AirPuffObj.setDuration('R',obj.puffDurSecs*1000);

    % Prepare the stimuli for the first interval
    obj.AirPuffObj.setPressure('L',intervalParams(1,1));
    obj.AirPuffObj.setPressure('R',intervalParams(1,1));

    obj.waitUntil(stopTimeSeconds);
    
    % Define the duration of the first interval
    stopTimeSeconds = cputime() + obj.isiSecs;

    % Play the first interval sound
    audioObjs.low.play;

    % Simultaneous, bilateral puff
    obj.AirPuffObj.triggerPuff('ALL');

    % Pause for the duration of the puff
    pause(obj.puffDurSecs);

    % Prepare the stimuli for the second interval
    obj.AirPuffObj.setPressure('L',intervalParams(2,1));
    obj.AirPuffObj.setPressure('R',intervalParams(2,1));

    % Finish waiting out the first interval
    obj.waitUntil(stopTimeSeconds);

    % Play the second interval tone tone
    audioObjs.mid.play;

    % Simultaneous, bilateral puff
    obj.AirPuffObj.triggerPuff('ALL');

end

% Start the response interval
if ~simulateResponse
    FlushEvents
    [intervalChoice, responseTimeSecs] = obj.getResponse();
else
    intervalChoice = obj.getSimulatedResponse(testParam,testInterval);
    responseTimeSecs = nan;
end

% Determine if the subject has selected the more intense interval and
% handle audio feedback
if intervalChoice==moreIntenseInterval
    % Correct
    correct = true;
    outcome = 2;
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
    outcome = 1;
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

if ~simulateStimuli

    % Wait a variable amount of time for the inter-trial-interval
    itiDur = min(itiRangeSecs)+range(itiRangeSecs)*rand();
    stopTimeSeconds = cputime() + obj.isiSecs;

    % Finish waiting out the ITI
    obj.waitUntil(stopTimeSeconds);

end
% Finish the line of text output
if obj.verbose
    fprintf('\n');
end

% Update questData
questData = qpUpdate(questData,testParam,outcome);

% Add in the stimulus information
questData.trialData(currTrialIdx).testInterval = testInterval;
questData.trialData(currTrialIdx).moreIntenseInterval = moreIntenseInterval;
questData.trialData(currTrialIdx).responseTimeSecs = responseTimeSecs;
questData.trialData(currTrialIdx).itiDur = itiDur;
questData.trialData(currTrialIdx).correct = correct;

% Put staircaseData back into the obj
obj.questData = questData;

end