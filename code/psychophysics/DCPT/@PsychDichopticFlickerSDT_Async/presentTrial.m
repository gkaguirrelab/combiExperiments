function presentTrial(obj,forceTestParam)

% Handle the nargin for forceTestParam. If the forceTestParam is passed,
% then the closest value within stimParamsDomainList is used for the
% testParam for the trial.
if nargin == 2
    stimParamsDomainList = obj.stimParamsDomainList;
    [~,stimIdx] = min(abs(stimParamsDomainList-forceTestParam));
    forceTestParam = stimParamsDomainList(stimIdx);
else
    forceTestParam = [];
end

% Get the EOGControl
EOGControl = obj.EOGControl;

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

% If forceTestParam is set, then use this value
if ~isempty(forceTestParam)
    testParam = forceTestParam;
else
    % We enhance the proportion of trials that present a 0 db stimulus at
    % the start of the measurement. The probability of a forced 0 dB trial
    % starts at 0.5, and then falls to zero following a decaying
    % exponential under the control of a parameter. The value used reaches
    % a probability of 0.1 after about 30 trials.
    nullTrialProbTimeConstant = 0.99;
    if rand() < 0.5 * nullTrialProbTimeConstant ^ currTrialIdx
        testParam = 0;
    else
        % Get the testParam to use for this trial using QUEST+
        testParam = qpQuery(questData);
    end
end

% The difference between the reference and test frequency is given by the
% testParam, which is in units of decibels. The stimParamSide setting tells
% us if we are setting the test frequency higher or lower than the ref.
switch obj.stimParamSide
    case 'hi'
        testFreqHz = refFreqHz * db2pow(testParam);
    case 'low'
        testFreqHz = refFreqHz / db2pow(testParam);
    otherwise
        error('not a valid stimParamSide setting')
end

% Define the stimulus params. This is a 2x3 vector with the dimensions
% corresponding to:
%       combiLED (1 or 2) and param (contrast, freq,phase)
stimParams = zeros(2,3);

% Define the parameters for the interval. One of the sides presents
% the test frequency. This is selected at random.
testSide = 1+round(rand());
refSide = mod(testSide,2)+1;

% Define the phase parameters for the interval. The phase is
% randomly selected and set to be pi/2 out of phase between the two sides.
% We have considered accounting for the delay in starting the 2nd combiLED
% relative to the first, but have decided this is too small of an effect to
% address.
testSidePhase = rand()*pi;
stimParams(1,3) = testSidePhase;
if testSide == 1
    stimParams(2,3) = wrapTo2Pi(testSidePhase + pi/2 + ...
        2 * pi * refFreqHz);
else
    stimParams(2,3) = wrapTo2Pi(testSidePhase + pi/2 + ...
        2 * pi * testFreqHz);
end

% Assign the refSide stimuli.
stimParams(refSide,1) = ...
    relativePhotoContrastCorrection(refSide) * ...
    (refModContrast / contrastAttenuationByFreq(refFreqHz));
stimParams(refSide,2) = refFreqHz;

% Assign the testSide stimuli
stimParams(testSide,1) = ...
    relativePhotoContrastCorrection(testSide) * ...
    (testModContrast / contrastAttenuationByFreq(testFreqHz));
stimParams(testSide,2) = testFreqHz;

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
    fprintf('Trial %d; Ref Contrast %2.2f; Ref freq %2.2f, Test freq %2.2f; Test side %d...', ...
        currTrialIdx,stimParams(1,1),stimParams(refSide,2),stimParams(testSide,2),testSide);
end

% Present the stimuli
if simulateMode

    %% Simulate
    answerChoice = obj.getSimulatedResponse(testParam);
    responseTimeSecs = nan;
    EOGdata = nan;

else

    %% Stimulus

    tic;

    % Prepare the combiLEDs
    for side = 1:2
        obj.CombiLEDObjArr{side}.setContrast(stimParams(side,1));
        obj.CombiLEDObjArr{side}.setFrequency(stimParams(side,2));
        obj.CombiLEDObjArr{side}.setPhaseOffset(stimParams(side,3));
    end

    % Add the start delay to the right side combiLED
    obj.CombiLEDObjArr{2}.setStartDelay(obj.stimDurSecs);

    toc;

    % Wait half a second to make sure that the CombiLEDs have received
    % these new settings
    stopTime = cputime() + 0.5;
    obj.waitUntil(stopTime);

    % Start the left stimulus and sound a tone. The right stimulus will
    % start after a delay time of stimDurSecs.
    for side = [1 2]
        obj.CombiLEDObjArr{side}.startModulation;
    end
    audioObjs.low.play;

   % Define the time at which the stimulus will end (twice the time of one
   % stimulus, since they go one after the other)
   stopTime = cputime() + 2*obj.stimDurSecs + obj.trialStartDelaySecs;

    % Start the EOG recording. This is a modal operation, so we are paused
    % here until the recording stops.
    if ~isempty(EOGControl)
        EOGControl.trialDurationSecs = obj.stimDurSecs;
        EOGdata = EOGControl.recordTrial();
    else
        EOGdata = [];
    end

    % Finish waiting for the stimulus to end
    obj.waitUntil(stopTime);

    % Play a tone to indicate end of stimulus presentation
    audioObjs.mid.play;

    % Start the response interval
    if obj.useKeyboardFlag
        [keyPress, responseTimeSecs] = getKeyboardResponse(currKeyPress,Inf,{'1','2','numpad1','numpad2', ...
            'leftarrow', 'rightarrow'});
        if ~isempty(keyPress)
            switch keyPress
                case {'1','numpad1','uparrow'}
                    answerChoice = 1;
                case {'2','numpad2','downarrow'}
                    answerChoice = 2;
            end
        end
        % Close the response window
        close(S.fh);
    else
        % Using gamepad
        [buttonPress, responseTimeSecs] = getGamepadResponse(Inf,[5 7 6 8]);
        if ~isempty(buttonPress)
            switch buttonPress
                case {5 6}   % Upper bumpers on the gamepad 
                    answerChoice = 1;  % same
                case {7 8}   % Lower bumpers on the gamepad
                    answerChoice = 2;   % different
            end
        end
    end

    % Wait for an inter-trial-interval. This is in addition to the one
    % second of delay at the start of the trial (0.5 seconds to allow the
    % EOG to start, and 0.5 seconds to allow the combiLEDs to receive
    % instructions)
    stopTime = cputime() + 0.5;
    obj.waitUntil(stopTime);

end

% The adaptive procedure is operates upon "same / different" responses. We
% handle this outcome here
outcome = answerChoice;
respondYes = logical(answerChoice-1);

% A correct response occurs when:
%   testParam ~= 0 and answerChoice == 2 (a "hit")
%   testParam == 0 and answerChoice == 1 (a "correct rejection");
% An incorrect occurs otherwise, and is a "false alarm" or a "miss"
if and(testParam~=0,answerChoice==2) || and(testParam==0,answerChoice==1)
    % Correct
    correct = true;
    if obj.verbose
        if and(testParam~=0,answerChoice==2)
            fprintf('hit');
        else
            fprintf('correct rejection');
        end
    end
    if ~simulateMode
        % We are not simulating, and the response was correct.
        % Regardless of whether we are giving feedback or not, we will
        % play the "correct" tone
        audioObjs.correct.play;
        obj.waitUntil(cputime()+1);
    end    
else
    % Incorrect
    correct = false;
    if obj.verbose
        if and(testParam~=0,answerChoice==1)
            fprintf('miss');
        else
            fprintf('false alarm');
        end
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
questData.trialData(currTrialIdx).responseTimeSecs = responseTimeSecs;
questData.trialData(currTrialIdx).correct = correct;
questData.trialData(currTrialIdx).respondYes = respondYes;
questData.trialData(currTrialIdx).EOGdata = EOGdata;

% Put staircaseData back into the obj
obj.questData = questData;

end