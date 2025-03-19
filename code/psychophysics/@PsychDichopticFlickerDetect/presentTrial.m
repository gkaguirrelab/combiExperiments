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

% Determine if we are randomly assigning the reference flicker on each trial,
% or fixing it to CombiLED A
randomCombi = obj.randomCombi;

% The calling function sets the reference frequency
testFreqHz = obj.testFreqHz;

% Get the stimParam to use for this trial. Can use either a staircase or
% QUEST+
if obj.useStaircase
    stimParam = obj.staircase(currTrialIdx);
else
    % The test contrast is provided by Quest+ in log units. Convert it hear to
    % linear
    qpStimParams = qpQuery(questData);
    testContrast = 10^qpStimParams;
end

% Adjust the contrast that is sent to the device to account for any
% device attenuation of the modulation at high temporal frequencies
testContrastAdjusted =  testContrast / contrastAttenuationByFreq(testFreqHz);

% The ref phase is always 0
refPhase = round(rand())*pi;

% Determine if we have random test phase or not
if obj.randomizePhase
    testPhase = round(rand())*pi;
else
    testPhase = refPhase + pi/2;
    if testPhase > 2*pi
        testPhase = refPhase - pi/2;
    end
end

% Assemble the param sets
testParams = [testContrastAdjusted,testFreqHz,testPhase];
refParams = [0,testFreqHz,0];

if randomCombi
    % OPTION 1: Randomly assign the stimuli to the intervals
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
else
    % OPTION 2: Fix the reference flicker to the first interval,
    % and thus to Combi LED A. 
    intervalParams(1,:) = refParams;
    intervalParams(2,:) = testParams;
    testInterval = 2;
end

% Note which interval contains the higher contrast, which is used for
% feedback
[~,higherContrast] = max(intervalParams(:,1));

% Prepare the sounds
Fs = 8192; % Sampling Frequency
dur = 0.1; % Duration in seconds
t  = linspace(0, dur, round(Fs*dur));

% Set a longer time for incorrect tone
longerDur = 0.30;
longerTime = linspace(0, longerDur, round(Fs*longerDur));

lowTone = sin(2*pi*500*t);
midTone = sin(2*pi*750*t);
highTone = sin(2*pi*1000*t);
incorrectTone1 = sin(2*pi*250*longerTime);
incorrectTone2 = sin(2*pi*425*longerTime);

readySound = [highTone highTone highTone];
correctSound = [lowTone midTone highTone];
incorrectSound = incorrectTone1 + incorrectTone2;

audioObjs.low = audioplayer(lowTone,Fs);
audioObjs.mid = audioplayer(midTone,Fs);
audioObjs.high = audioplayer(highTone,Fs);
audioObjs.ready = audioplayer(readySound,Fs);
audioObjs.correct = audioplayer(correctSound,Fs);
audioObjs.incorrect = audioplayer(incorrectSound,Fs);

% Create a figure that will be used to collect key presses
if ~simulateResponse
    [currKeyPress,S] = createResponseWindow();
end

% Handle verbosity
if obj.verbose
    fprintf('Trial %d; Freq [%2.2f, %2.2f Hz], Contrast [%2.2f, %2.2f]... ', ...
        currTrialIdx,intervalParams(1,2),intervalParams(2,2), ...
        intervalParams(1,1), intervalParams(2,1));
end

% Present the stimuli
if ~simulateStimuli

    % Alert the subject the trial is about to start
    stopTimeSeconds = cputime() + 1;
    obj.waitUntil(stopTimeSeconds);

    % Present the two intervals simultaneously
    % Prepare the stimulus
    stopTime = cputime() + obj.interStimulusIntervalSecs;

    obj.CombiLEDObjC.setContrast(intervalParams(1,1));
    obj.CombiLEDObjC.setFrequency(intervalParams(1,2));
    obj.CombiLEDObjC.setPhaseOffset(intervalParams(1,3));

    obj.CombiLEDObjD.setContrast(intervalParams(2,1));
    obj.CombiLEDObjD.setFrequency(intervalParams(2,2));
    obj.CombiLEDObjD.setPhaseOffset(intervalParams(2,3));

    obj.waitUntil(stopTime);

    % Present the stimuli. Wait 1/4 of the stimuli and then move on to 
    % the response, thus allowing the subject to respond during the stimuli. 
    stopTime = cputime() + 0.5;

    obj.CombiLEDObjC.startModulation;
    obj.CombiLEDObjD.startModulation;
    audioObjs.low.play;
    obj.waitUntil(stopTime);

end

% Start the response interval
if ~simulateResponse
    [keyPress, responseTimeSecs] = getResponse(currKeyPress,Inf,{'1','2','numpad1','numpad2', ...
        'leftarrow', 'rightarrow'});
    switch keyPress
        case {'1','numpad1','leftarrow'}
            intervalChoice = 1;
        case {'2','numpad2','rightarrow'}
            intervalChoice = 2;
    end
    close(S.fh);
else
    intervalChoice = obj.getSimulatedResponse(stimParam,testInterval);
    responseTimeSecs = nan;
end

% Stop the stimulus in case it is still running
if ~simulateStimuli
    obj.CombiLEDObjC.stopModulation;
    obj.CombiLEDObjD.stopModulation;
end

% Determine if the subject has selected the ref or test interval
if intervalChoice == testInterval
    outcome = 2;
else
    outcome = 1;
end

% Determine if the subject has selected the faster interval and handle
% audio feedback
if intervalChoice==higherContrast
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
        obj.waitUntil(cputime()+1);
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
        obj.waitUntil(cputime()+1);
    end
end

% Finish the line of text output
if obj.verbose
    fprintf('\n');
end

% Update questData
questData = qpUpdate(questData,qpStimParams,outcome);

% Add in the stimulus information
questData.trialData(currTrialIdx).testPhase = testPhase;
questData.trialData(currTrialIdx).testInterval = testInterval;
questData.trialData(currTrialIdx).fasterInterval = higherContrast;
questData.trialData(currTrialIdx).responseTimeSecs = responseTimeSecs;
questData.trialData(currTrialIdx).correct = correct;

% Put staircaseData back into the obj
obj.questData = questData;

end