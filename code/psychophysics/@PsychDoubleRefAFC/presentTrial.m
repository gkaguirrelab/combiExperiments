function validResponse = presentTrial(obj)

% Get the questData
questData = obj.questData;

% Get the current trial index
currTrialIdx = size(questData.trialData,1)+1;

% Determine if we are simulating the stimuli
simulateStimuli = obj.simulateStimuli;
simulateResponse = obj.simulateResponse;

% Determine if we are giving feedback on each trial
giveFeedback = obj.giveFeedback;

% The contrast levels of the stimuli are set by the calling routine
testContrastAdjusted = obj.testContrastAdjusted;

% The test frequency is set by the calling function
testFreqHz = obj.testFreqHz;

% Get the frequency parameters are provided by Quest+
qpStimParams = qpQuery(questData);

% The qpStimParams are in relative log units. Convert them here to
% absolute, linear frequency for presentation to the subject
ref1FreqHz = obj.inverseTransVals(qpStimParams(1),testFreqHz);
ref2FreqHz = obj.inverseTransVals(qpStimParams(2),testFreqHz);

% Adjust the contrast of the stimulus to account for device attenuation of
% the modulation at high temporal frequencies
[~,ref1FreqIdx] = min(abs(obj.refFreqSetHz-ref1FreqHz));
[~,ref2FreqIdx] = min(abs(obj.refFreqSetHz-ref2FreqHz));
ref1ContrastAdjusted = obj.refContrastVectorAdjusted(ref1FreqIdx);
ref2ContrastAdjusted = obj.refContrastVectorAdjusted(ref2FreqIdx);

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

% Determine if we have random phase or not
if obj.randomizePhase
    refPhase = round(rand())*pi;
    testPhase = round(rand())*pi;
else
    refPhase = 0;
    testPhase = 0;
end

% Assemble the param sets
ref1Params = [ref1ContrastAdjusted,ref1FreqHz,refPhase];
ref2Params = [ref2ContrastAdjusted,ref2FreqHz,refPhase];
testParams = [testContrastAdjusted,testFreqHz,testPhase];

% Randomly pick which interval contains ref1
ref1Interval = 1+logical(round(rand()));

% Assign the stimuli to the intervals
switch ref1Interval
    case 1
        intervalParams(1,:) = ref1Params;
        intervalParams(2,:) = ref2Params;
    case 2
        intervalParams(1,:) = ref2Params;
        intervalParams(2,:) = ref1Params;
    otherwise
        error('Not a valid ref1Interval')
end

% Handle verbosity
if obj.verbose
    fprintf('Trial %d; test [%2.2f]; int1 [%2.2f]; int2 [%2.2f]...', ...
        currTrialIdx,testParams(2),intervalParams(1,2),intervalParams(2,2));
end

% Present the stimuli
if ~simulateStimuli

    % Alert the subject the trial is about to start
    audioObjs.ready.play;
    stopTime = tic() + 1e9;
    obj.waitUntil(stopTime);

    % Present the two intervals
    for ii=1:2

        % Within each interval, alternate between the reference and the
        % test twice
        for ss=1:2

            % Prepare the reference stimulus
            stopTime = tic() + obj.interFlickerIntervalSecs*1e9;
            obj.CombiLEDObj.setContrast(intervalParams(ii,1));
            obj.CombiLEDObj.setFrequency(intervalParams(ii,2));
            obj.CombiLEDObj.setPhaseOffset(intervalParams(ii,3));
            obj.waitUntil(stopTime);

            % Present a reference stimulus
            stopTime = tic() + obj.stimulusDurationSecs*1e9;
            obj.CombiLEDObj.startModulation;
            if ii==1
                audioObjs.low.play;
            else
                audioObjs.high.play;
            end
            obj.waitUntil(stopTime);

            % Prepare the test stimulus
            stopTime = tic() + obj.interFlickerIntervalSecs*1e9;
            obj.CombiLEDObj.setContrast(testParams(1));
            obj.CombiLEDObj.setFrequency(testParams(2));
            obj.CombiLEDObj.setPhaseOffset(testParams(3));
            obj.waitUntil(stopTime);

            % Present the test stimulus.
            stopTime = tic() + obj.stimulusDurationSecs*1e9;
            obj.CombiLEDObj.startModulation;
            audioObjs.mid.play;
            obj.waitUntil(stopTime);

        end

        % ISI
        if ii==1
            stopTime = stopTime + obj.interStimulusIntervalSecs*1e9;
            obj.waitUntil(stopTime);
        end
    end
end

% Start the response interval
if ~simulateResponse
    [intervalChoice, responseTimeSecs] = obj.getResponse;
    % Make sure the stimulus has stopped
    obj.CombiLEDObj.stopModulation;
else
    [intervalChoice, responseTimeSecs] = obj.getSimulatedResponse(qpStimParams,ref1Interval);
end

% Determine if the subject has selected reference One or Two
if ~isempty(intervalChoice)
    validResponse = true;
    if ref1Interval==intervalChoice
        % The subject said that reference 1 is more similar to the test
        outcome = 1;
    else
        outcome = 2;
    end
else
    outcome = nan;
    validResponse = false;
end

if obj.verbose
    fprintf('choice = %d', intervalChoice);
end

% Handle feedback at the end of the trial
if giveFeedback && validResponse
    % If we are giving feedback, determine if the subject correctly
    % selected the interval with the frequency that is closer to the test
    [~,correctReference] = min(abs(qpStimParams));
    if outcome == correctReference
        if ~simulateStimuli
            audioObjs.correct.play;
        end
        if obj.verbose
            fprintf('; correct');
        end
    else
        if ~simulateStimuli
            audioObjs.incorrect.play;
        end
        if obj.verbose
            fprintf('; incorrect');
        end
    end
    if ~simulateStimuli
        obj.waitUntil(tic()+5e8);
    end
end

if obj.verbose
    fprintf('\n');
end

if ~giveFeedback && validResponse
    % If we aren't giving feedback, but the subject did make a valid
    % response, we give the same, pleasing tone after every trial.
    if ~simulateStimuli
        audioObjs.correct.play;
    end
end

% Update questData if a valid response
if validResponse
    % Update questData
    questData = qpUpdate(questData,qpStimParams,outcome);

    % Add in the phase and interval information
    questData.trialData(currTrialIdx).phases = [refPhase,testPhase];
    questData.trialData(currTrialIdx).ref1Interval = ref1Interval;
    questData.trialData(currTrialIdx).responseTimeSecs = responseTimeSecs;
else
    % Buzz the bad trial
    if ~simulateStimuli
        audioObjs.bad.play;
    end
    obj.waitUntil(tic()+3e9);

    % Store a note that we had an invalid response
    if ~isfield(questData,'invalidResponseTrials')
        questData.invalidResponseTrials = currTrialIdx;
    else
        questData.invalidResponseTrials(end+1) = currTrialIdx;
    end
end

% Put questData back into the obj
obj.questData = questData;


end