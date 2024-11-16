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

% The calling function sets the refPuffPSI and the duration of each puff
refPuffPSI = obj.refPuffPSI;
stimulusDurationSecs = obj.stimulusDurationSecs;

% Get the stimParam to use for this trial. Can use either a staircase or
% QUEST+
if obj.useStaircase
    stimParam = obj.staircase(currTrialIdx);
else
    stimParam = qpQuery(questData);
end

% The difference between the reference and test frequency is given by the
% qpStimParam, which is in units of decibels
testPuffPSI = refPuffPSI * db2pow(stimParam);

% Assemble the param sets
testParams = [stimulusDurationSecs,testPuffPSI];
refParams = [stimulusDurationSecs,refPuffPSI];

% Randomly assign the stimuli to the intervals
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
        error('Not a valid testInterval')
end

% Note which interval contains the more intense stimulus, which is used for
% feedback
[~,moreIntenseInterval] = max(intervalParams(:,2));

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

% Create a figure that will be used to collect key presses
if ~simulateResponse
    [currKeyPress,S] = createResponseWindow();
end

% Handle verbosity
if obj.verbose
    fprintf('Trial %d; Pressure PSI [%2.2f, %2.2f Hz]...', ...
        currTrialIdx,intervalParams(1,2),intervalParams(2,2));
end

% Present the stimuli
if ~simulateStimuli

    % Alert the subject the trial is about to start
    audioObjs.ready.play;
    stopTimeSeconds = cputime() + 1;
    obj.waitUntil(stopTimeSeconds);

    % Present the two intervals
    for ii=1:2

        % Prepare the stimulus
        obj.CombiAirObj.setDurationDirect(intervalParams(ii,1)*1000);
        obj.CombiAirObj.setPressureDirect(intervalParams(ii,2));

        % Present the stimulus. If it is the first interval, wait the
        % entire stimulusDuration. If it is the second interval. just wait
        % 1/4 of the stimulus and then move on to the response, thus
        % allowing the subject to respond during the second stimulus.
        if ii == 1
            stopTime = cputime() + obj.stimulusDurationSecs + obj.interStimulusIntervalSecs;
        else
            stopTime = cputime() + 0.25*obj.stimulusDurationSecs;
        end
        obj.CombiAirObj.triggerPuffDirect;
        if ii==1
            audioObjs.low.play;
        else
            audioObjs.high.play;
        end
        obj.waitUntil(stopTime);
    end
end

% Start the response interval
if ~simulateResponse
    [keyPress, responseTimeSecs] = getResponse(currKeyPress,Inf,{'1','2','numpad1','numpad2'});
    switch keyPress
        case {'1','numpad1'}
            intervalChoice = 1;
        case {'2','numpad2'}
            intervalChoice = 2;
    end
    close(S.fh);
else
    intervalChoice = obj.getSimulatedResponse(stimParam,testInterval);
    responseTimeSecs = nan;
end

% Set the pressure back to zero
if ~simulateStimuli
    obj.CombiAirObj.setPressureDirect(0);
end

% Determine if the subject has selected the ref or test interval
if intervalChoice == testInterval
    outcome = 2;
else
    outcome = 1;
end

% Determine if the subject has selected the faster interval and handle
% audio feedback
if intervalChoice==moreIntenseInterval
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
        obj.waitUntil(cputime()+0.5);
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
            audioObjs.correct.play;
        end
        obj.waitUntil(cputime()+0.5);
    end
end

% Finish the line of text output
if obj.verbose
    fprintf('\n');
end

% Update questData
questData = qpUpdate(questData,stimParam,outcome);

% Add in the stimulus information
questData.trialData(currTrialIdx).testInterval = testInterval;
questData.trialData(currTrialIdx).fasterInterval = moreIntenseInterval;
questData.trialData(currTrialIdx).responseTimeSecs = responseTimeSecs;
questData.trialData(currTrialIdx).correct = correct;

% Put staircaseData back into the obj
obj.questData = questData;

end