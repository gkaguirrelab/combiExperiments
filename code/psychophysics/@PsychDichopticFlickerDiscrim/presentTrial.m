function presentTrial(obj)

% Get the questData
questData = obj.questData;

% Get the current trial index
currTrialIdx = size(questData.trialData,1)+1;

% Determine if we are simulating the stimuli and observer
simulateMode = obj.simulateMode;

% Determine if we are giving feedback on each trial
giveFeedback = obj.giveFeedback;

% The calling function sets the reference frequency, and the contrast of
% the test and ref
refFreqHz = obj.refFreqHz;
refModContrast = obj.refModContrast;
testModContrast = obj.testModContrast;

% Get the adjustment for the relative difference in photoreceptor contrast
% between the two modResults / combiLEDs
relativePhotoContrastCorrection = obj.relativePhotoContrastCorrection;

% Get the testParam to use for this trial. Can use either a staircase or
% QUEST+
if obj.useStaircase
    testParam = obj.staircase(currTrialIdx);
else
    testParam = qpQuery(questData);
end

% The difference between the reference and test frequency is given by the
% testParam, which is in units of decibels
testFreqHz = refFreqHz * db2pow(testParam);

% Define the stimulus params. This is a 2x2x3 vector with the dimensions
% corresponding to:
%       interval, combiLED (1 or 2), and param (contrast, freq,phase)
stimParams = zeros(2,2,3);

% Decide which inteval will have the test flicker.
testInterval = 1+round(rand());
refInterval = mod(testInterval,2)+1;

% Define the phase parameters for the reference interval. The phase is
% randomly selected and set to be pi/2 out of phase between the two sides.
% We also need to account for the delay in starting the 2nd combiLED
% relative to the first.
refIntervalPhaseBySide(1) = rand()*pi;
refIntervalPhaseBySide(2) = wrapTo2Pi(refIntervalPhaseBySide(1) + pi/2 + ...
           2 * pi * refFreqHz * obj.combiLEDStartTimeSecs);

% Set the parameters for the reference interval. The same contrast and
% frequency is shown on the two sides. 
for side = 1:2
    % Contrast
    stimParams(refInterval,side,1) = ...
        relativePhotoContrastCorrection(side) * ...
        (refModContrast / contrastAttenuationByFreq(refFreqHz));
    % Frequency
    stimParams(refInterval,side,2) = refFreqHz;
    % Phase 
    stimParams(refInterval,side,3) = refIntervalPhaseBySide(side);
end

% During the parameters for the test interval. One of the sides presents
% the test frequency. This is selected at random.
testSide = 1+round(rand());
refSide = mod(testSide,2)+1;

% Define the phase parameters for the test interval. The phase is
% randomly selected and set to be pi/2 out of phase between the two sides.
% We also need to account for the delay in starting the 2nd combiLED
% relative to the first.
testIntervalPhaseSide1 = rand()*pi;
stimParams(testInterval,1,3) = testIntervalPhaseSide1;
if testSide == 1
    stimParams(testInterval,2,3) = wrapTo2Pi(testIntervalPhaseSide1 + pi/2 + ...
        2 * pi * refFreqHz * obj.combiLEDStartTimeSecs);
else
    stimParams(testInterval,2,3) = wrapTo2Pi(testIntervalPhaseSide1 + pi/2 + ...
        2 * pi * testFreqHz * obj.combiLEDStartTimeSecs);
end

% Assign the refSide stimuli for the test interval.
stimParams(testInterval,refSide,1) = ...
    relativePhotoContrastCorrection(refSide) * ...
    (refModContrast / contrastAttenuationByFreq(refFreqHz));
stimParams(testInterval,refSide,2) = refFreqHz;

% Assign the testSide stimuli for the test interval.
stimParams(testInterval,testSide,1) = ...
    relativePhotoContrastCorrection(testSide) * ...
    (testModContrast / contrastAttenuationByFreq(testFreqHz));
stimParams(testInterval,testSide,2) = testFreqHz;

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

% Create a figure that will be used to collect key presses if we are using
% the keyboard
if ~simulateMode && obj.useKeyboardFlag
    [currKeyPress,S] = createResponseWindow();
end

% Handle verbosity
if obj.verbose
    fprintf('Trial %d; Ref Contrast %2.2f; Ref freq %2.2f, Test freq %2.2f; Test Interval %d, Test side %d...', ...
        currTrialIdx,stimParams(1,1,1),stimParams(testInterval,refSide,2),stimParams(testInterval,testSide,2),testInterval,testSide);
end

% Present the stimuli
if simulateMode

    %% Simulate
    intervalChoice = obj.getSimulatedResponse(testParam,testSide);
    responseTimeSecs = nan;
else

    %% First interval

    % Prepare the combiLEDs
    interval = 1;
    for side = 1:2
       obj.CombiLEDObjArr{side}.setContrast(stimParams(interval,side,1));
       obj.CombiLEDObjArr{side}.setFrequency(stimParams(interval,side,2));
       obj.CombiLEDObjArr{side}.setPhaseOffset(stimParams(interval,side,3));
    end

    % Wait half a second to make sure that the CombiLEDs have received
    % these new settings
    stopTime = cputime() + 0.5;
    obj.waitUntil(stopTime);

    % Start the stimuli and sound a tone. Wait for stimDurSecs.
    stopTime = cputime() + obj.stimDurSecs;
    for side = 1:2
        obj.CombiLEDObjArr{side}.startModulation;
    end
    audioObjs.low.play;
    obj.waitUntil(stopTime);

    %% Second interval

    % During the ISI, prepare the stimuli. Only update the side that
    % contained the test stimulus (the reference side will be unchanged)
    interval = 2;
    tic
    stopTime = cputime() + obj.isiSecs;
    obj.CombiLEDObjArr{testSide}.setContrast(stimParams(interval,testSide,1));
    obj.CombiLEDObjArr{testSide}.setFrequency(stimParams(interval,testSide,2));
    obj.CombiLEDObjArr{testSide}.setPhaseOffset(stimParams(interval,testSide,3));
    obj.waitUntil(stopTime);
    toc

    % Start the stimuli and sound a tone. Wait a half a second so that the
    % subject has to look at these for a moment. 
    stopTime = cputime() + 0.5;
    for side = 1:2
        obj.CombiLEDObjArr{side}.startModulation;
    end
    audioObjs.mid.play;
    obj.waitUntil(stopTime);

    % Start the response interval
    if obj.useKeyboardFlag
        [keyPress, responseTimeSecs] = getKeyboardResponse(currKeyPress,Inf,{'1','2','numpad1','numpad2', ...
            'leftarrow', 'rightarrow'});
        if ~isempty(keyPress)
            switch keyPress
                case {'1','numpad1','leftarrow'}
                    intervalChoice = 1;
                case {'2','numpad2','rightarrow'}
                    intervalChoice = 2;
            end
        end
        % Close the response window
        close(S.fh);
    else
        % Using gamepad
        [buttonPress, responseTimeSecs] = getGamepadResponse(Inf,[5 7 6 8]);
        if ~isempty(buttonPress)
            switch buttonPress
                case {5 7}
                    intervalChoice = 1;
                case {6 8}
                    intervalChoice = 2;
            end
        end
    end

    % Stop the stimuli (needed as the subject may have responded before the
    % stimuli have completed)
    for side = 1:2
        obj.CombiLEDObjArr{side}.stopModulation;
    end

    % Wait half a second for an inter-trial-interval
    stopTime = cputime() + 0.5;
    obj.waitUntil(stopTime);

end

% We define a correct response as selecting the interval that contains the
% test stimulus. Determine if the subject has selected the correct interval
% and handle audio feedback
if intervalChoice==testInterval
    % Correct
    outcome = 2;
    correct = true;
    if obj.verbose
        fprintf('correct');
    end
    if ~simulateMode
        % We are not simulating, and the response was correct.
        % Regardless of whether we are giving feedback or not, we will
        % play the "correct" tone
        audioObjs.correct.play;
        obj.waitUntil(cputime()+1);
    end
else
    % incorrect
    outcome = 1;
    correct = false;
    if obj.verbose
        fprintf('incorrect');
    end
    if ~simulateMode
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
questData = qpUpdate(questData,testParam,outcome);

% Add in the stimulus information
questData.trialData(currTrialIdx).stimParams = stimParams;
questData.trialData(currTrialIdx).refSide = refSide;
questData.trialData(currTrialIdx).testSide = testSide;
questData.trialData(currTrialIdx).refInterval = refInterval;
questData.trialData(currTrialIdx).testInterval = testInterval;
questData.trialData(currTrialIdx).responseTimeSecs = responseTimeSecs;
questData.trialData(currTrialIdx).correct = correct;

% Put staircaseData back into the obj
obj.questData = questData;

end