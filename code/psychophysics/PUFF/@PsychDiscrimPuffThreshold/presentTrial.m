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

% Give labels to the sides
sides = {'L','R'};

% Randomly assign the stimuli to the sides [L,R]
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
        error('Not a valid testSide')
end

% Note which interval contains the more intense stimulus, which is used for
% feedback
[~,moreIntenseSide] = max(sideParams(:,2));

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
    fprintf('Trial %d; Pressure PSI [%2.2f, %2.2f PSI]...', ...
        currTrialIdx,sideParams(1,2),sideParams(2,2));
end

% Present the stimuli
if ~simulateStimuli

    % Alert the subject the trial is about to start and set a timer
    audioObjs.ready.play;
    stopTimeSeconds = cputime() + 1;

    % Prepare the stimuli
    for ss = 1:length(sides)
        obj.AirPuffObj.setDuration(sides{ss},sideParams(ss,1)*1000);
        pause(0.2);
        obj.AirPuffObj.setPressure(sides{ss},sideParams(ss,2));
        pause(0.2);
    end

    % Wait until the stop time
    obj.waitUntil(stopTimeSeconds);

    % Simultaneous, bilateral puff
    obj.AirPuffObj.triggerPuff('B');

% Start the response interval
if ~simulateResponse
    [keyPress, responseTimeSecs] = getResponse(currKeyPress,Inf,{'1','2','numpad1','numpad2'});
    switch keyPress
        case {'1','numpad1'}
            sideChoice = 1;
        case {'2','numpad2'}
            sideChoice = 2;
    end
    close(S.fh);
else
    sideChoice = obj.getSimulatedResponse(stimParam,testSide);
    responseTimeSecs = nan;
end

% Set the pressure back to zero
if ~simulateStimuli
    for ss = 1:length(sides)
        obj.AirPuffObj.setPressure(sides{ss},0);
    end
end

% Determine if the subject has selected the ref or test side
if sideChoice == testSide
    outcome = 2;
else
    outcome = 1;
end

% Determine if the subject has selected the more intense side and handle
% audio feedback
if sideChoice==moreIntenseSide
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
questData.trialData(currTrialIdx).testSide = testSide;
questData.trialData(currTrialIdx).moreIntenseSide = moreIntenseSide;
questData.trialData(currTrialIdx).responseTimeSecs = responseTimeSecs;
questData.trialData(currTrialIdx).correct = correct;

% Put staircaseData back into the obj
obj.questData = questData;

end