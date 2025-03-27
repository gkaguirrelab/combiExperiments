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

% The calling function sets the reference frequency, and the contrast of
% the test and ref
refFreqHz = obj.refFreqHz;
refContrast = obj.refContrast;
testContrast = obj.testContrast;

% Get the stimParam to use for this trial. Can use either a staircase or
% QUEST+
if obj.useStaircase
    stimParam = obj.staircase(currTrialIdx);
else
    stimParam = qpQuery(questData);
end

% The difference between the reference and test frequency is given by the
% qpStimParam, which is in units of decibels
testFreqHz = refFreqHz * db2pow(stimParam);

% Adjust the contrast that is sent to the device to account for any
% device attenuation of the modulation at high temporal frequencies
testContrastAdjusted =  testContrast / contrastAttenuationByFreq(testFreqHz);
refContrastAdjusted =  refContrast / contrastAttenuationByFreq(refFreqHz);

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
refParams = [refContrastAdjusted,refFreqHz,refPhase];

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

% Note which interval contains the faster flicker, which is used for
% feedback
[~,fasterInterval] = max(intervalParams(:,2));

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
    fprintf('Trial %d; Freq [%2.2f, %2.2f Hz]...', ...
        currTrialIdx,intervalParams(1,2),intervalParams(2,2));
end

% Present the stimuli
if ~simulateStimuli

    % Alert the subject the trial is about to start
    stopTimeSeconds = cputime() + 1;
    obj.waitUntil(stopTimeSeconds);

    % Present the two intervals simultaneously
    % Prepare the stimulus
    stopTime = cputime() + obj.interStimulusIntervalSecs;

    obj.CombiLEDObjA.setContrast(intervalParams(1,1));
    obj.CombiLEDObjA.setFrequency(intervalParams(1,2));
    obj.CombiLEDObjA.setPhaseOffset(intervalParams(1,3));

    obj.CombiLEDObjB.setContrast(intervalParams(2,1));
    obj.CombiLEDObjB.setFrequency(intervalParams(2,2));
    obj.CombiLEDObjB.setPhaseOffset(intervalParams(2,3));

    obj.waitUntil(stopTime);

    % Present the stimuli. Wait 1/4 of the stimuli and then move on to 
    % the response, thus allowing the subject to respond during the stimuli. 
    stopTime = cputime() + 0.5;

    obj.CombiLEDObjA.startModulation;
    obj.CombiLEDObjB.startModulation;
    audioObjs.low.play;
    obj.waitUntil(stopTime);

end

% Start the response interval

% Choose between keyboard or gamepad input
keyboard = false;

if ~simulateResponse

    if keyboard % Using keyboard
        % Check for keyboard input
        [keyPress, responseTimeSecs] = getResponse(currKeyPress,Inf,{'1','2','numpad1','numpad2', ...
            'leftarrow', 'rightarrow'});

        if ~isempty(keyPress)
            switch keyPress
                case {'1','numpad1','leftarrow'}
                    intervalChoice = 1;
                case {'2','numpad2','rightarrow'}
                    intervalChoice = 2;
            end
        end

    else  % Using gamepad

        intervalStartSecs = second(datetime(),'secondofday');

        while true % Keep looping until a button is pressed

            % Check for gamepad input
            % Left side
            buttonState5 = Gamepad('GetButton', 1, 5); % 5th button on 1st gamepad
            buttonState7 = Gamepad('GetButton', 1, 7);
            % Right side
            buttonState6 = Gamepad('GetButton', 1, 6);
            buttonState8 = Gamepad('GetButton', 1, 8);

            if buttonState5 == 1 || buttonState7 == 1
                intervalChoice = 1;
                responseTimeSecs = second(datetime(),'secondofday') - intervalStartSecs;
                break
            elseif buttonState6 == 1 || buttonState8 == 1
                intervalChoice = 2;
                responseTimeSecs = second(datetime(),'secondofday') - intervalStartSecs;
                break
            end

        end

    end

    close(S.fh);
else
    intervalChoice = obj.getSimulatedResponse(stimParam,testInterval);
    responseTimeSecs = nan;
end

% Stop the stimulus in case it is still running
if ~simulateStimuli
    obj.CombiLEDObjA.stopModulation;
    obj.CombiLEDObjB.stopModulation;
end

% Determine if the subject has selected the ref or test interval
if intervalChoice == testInterval
    outcome = 2;
else
    outcome = 1;
end

% Determine if the subject has selected the faster interval and handle
% audio feedback
if intervalChoice==fasterInterval
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
questData = qpUpdate(questData,stimParam,outcome);

% Add in the stimulus information
questData.trialData(currTrialIdx).testPhase = testPhase;
questData.trialData(currTrialIdx).testInterval = testInterval;
questData.trialData(currTrialIdx).fasterInterval = fasterInterval;
questData.trialData(currTrialIdx).responseTimeSecs = responseTimeSecs;
questData.trialData(currTrialIdx).correct = correct;

% Put staircaseData back into the obj
obj.questData = questData;

end