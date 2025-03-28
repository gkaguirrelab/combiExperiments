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

% Get trial timing information
updateCombiLEDTimeSecs = obj.updateCombiLEDTimeSecs;
waitToRespondTimeSecs = obj.waitToRespondTimeSecs;

% Determine if we are randomly assigning the non-zero contrast flicker on
% each trial, or fixing it to CombiLED1
randomCombi = obj.randomCombi;

% The calling function sets the reference frequency
testFreqHz = obj.testFreqHz;

% Get the stimParam to use for this trial. Can use either a staircase or
% QUEST+
if obj.useStaircase
    stimParam = obj.staircase(currTrialIdx);
else
    % The test contrast is provided by Quest+ in log units. Convert it here
    % to linear
    qpStimParams = qpQuery(questData);
    testContrast = 10^qpStimParams;
end

% Adjust the contrast that is sent to the device to account for any
% device attenuation of the modulation at high temporal frequencies
testContrastAdjusted =  testContrast / contrastAttenuationByFreq(testFreqHz);

% Determine if we have random test phase or not
if obj.randomizePhase
    testPhase = rand()*pi;
else
    testPhase = 0;
end

% Assemble the param sets
testParams = [testContrastAdjusted,testFreqHz,testPhase];
refParams = [0,testFreqHz,0];

if randomCombi
    % OPTION 1: Randomly assign the stimuli to the left or right side eye
    % piece
    switch 1+logical(round(rand()))
        case 1
            sideParams(1,:) = testParams;
            sideParams(2,:) = refParams;
            testSide = 1;
        case 2
            sideParams(1,:) = refParams;
            sideParams(2,:) = testParams;
            testSide = 2;
        otherwise
            error('Not a valid testInterval')
    end
else
    % OPTION 2: Fix the reference flicker to combiLED1
    sideParams(1,:) = refParams;
    sideParams(2,:) = testParams;
    testSide = 2;
end

% Adjust the contrast again to null small differences in photoreceptor
% contrast between the modulations in the two combiLEDs
sideParams(:,1) = sideParams(:,1) .* obj.relativePhotoContrastCorrection';

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
    fprintf('Trial %d; Freq [%2.2f, %2.2f Hz], Contrast [%2.3f, %2.3f]... ', ...
        currTrialIdx,sideParams(1,2),sideParams(2,2), ...
        sideParams(1,1), sideParams(2,1));
end

% Present the stimuli
if ~simulateStimuli

    % Send the params to the CombiLEDs. Give some time for this to take
    % place.
    stopTime = cputime() + updateCombiLEDTimeSecs;

    obj.CombiLEDObj1.setContrast(sideParams(1,1));
    obj.CombiLEDObj1.setFrequency(sideParams(1,2));
    obj.CombiLEDObj1.setPhaseOffset(sideParams(1,3));

    obj.CombiLEDObj2.setContrast(sideParams(2,1));
    obj.CombiLEDObj2.setFrequency(sideParams(2,2));
    obj.CombiLEDObj2.setPhaseOffset(sideParams(2,3));

    obj.waitUntil(stopTime);

    % Start the stimuli. We present an alert tone immediately after
    % stimulus onset. The participant is allowed to respond any time after
    % waitToRespondTimeSecs
    stopTime = cputime() + waitToRespondTimeSecs;

    obj.CombiLEDObj1.startModulation;
    obj.CombiLEDObj2.startModulation;
    audioObjs.low.play;
    obj.waitUntil(stopTime);

end

% Start the response interval

if ~simulateResponse

    if obj.useKeyboardFlag % Using keyboard
        % Check for keyboard input
        [keyPress, responseTimeSecs] = getResponse(currKeyPress,Inf,{'1','2','numpad1','numpad2', ...
            'leftarrow', 'rightarrow'});

        if ~isempty(keyPress)
            switch keyPress
                case {'1','numpad1','leftarrow'}
                    sideChoice = 1;
                case {'2','numpad2','rightarrow'}
                    sideChoice = 2;
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
                sideChoice = 1;
                responseTimeSecs = second(datetime(),'secondofday') - intervalStartSecs;
                break
            elseif buttonState6 == 1 || buttonState8 == 1
                sideChoice = 2;
                responseTimeSecs = second(datetime(),'secondofday') - intervalStartSecs;
                break
            end

        end

    end

    close(S.fh);
else
    sideChoice = obj.getSimulatedResponse(stimParam,testInterval);
    responseTimeSecs = nan;
end

% Stop the stimulus in case it is still running
if ~simulateStimuli
    obj.CombiLEDObj1.stopModulation;
    obj.CombiLEDObj2.stopModulation;
end

% Determine if the subject has selected the ref or test interval
if sideChoice == testSide
    outcome = 2;
else
    outcome = 1;
end

% Determine if the subject has selected the faster interval and handle
% audio feedback
if sideChoice == testSide
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
questData.trialData(currTrialIdx).testSide = testSide;
questData.trialData(currTrialIdx).responseTimeSecs = responseTimeSecs;
questData.trialData(currTrialIdx).correct = correct;

% Put staircaseData back into the obj
obj.questData = questData;

end