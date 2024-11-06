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

% The reference frequency and the contrast of the test and ref is set by
% the calling function
refFreqHz = obj.refFreqHz;
refContrast = obj.refContrast;
testContrast = obj.testContrast;

% The difference between the test and reference frequency is given by qp
qpStimParam = qpQuery(questData);
testFreqHz = refFreqHz + qpStimParam;

% Adjust the contrast that is sent to the device to account for any
% device attenuation of the modulation at high temporal frequencies
testContrastAdjusted =  testContrast / contrastAttentionByFreq(testFreqHz);
refContrastAdjusted =  refContrast / contrastAttentionByFreq(refFreqHz);

% The ref phase is always 0
refPhase = 0;

% Determine if we have random test phase or not
if obj.randomizePhase
    testPhase = round(rand())*pi;
else
    testPhase = 0;
end

% Assemble the param sets
testParams = [testContrastAdjusted,testFreqHz,testPhase];
refParams = [refContrastAdjusted,refFreqHz,refPhase];

% Randomly pick which interval contains the test
testInterval = 1+logical(round(rand()));

% Assign the stimuli to the intervals
switch testInterval
    case 1
        intervalParams(1,:) = testParams;
        intervalParams(2,:) = refParams;
    case 2
        intervalParams(1,:) = refParams;
        intervalParams(2,:) = testParams;
    otherwise
        error('Not a valid testInterval')
end

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
currKeyPress='0';
S.fh = figure( 'units','pixels',...
    'position',[500 500 200 260],...
    'menubar','none','name','move_fig',...
    'numbertitle','off','resize','off',...
    'keypressfcn',@f_capturekeystroke,...
    'CloseRequestFcn',@f_closecq);
S.tx = uicontrol('style','text',...
    'units','pixels',...
    'position',[60 120 80 20],...
    'fontweight','bold');
guidata(S.fh,S)

% Handle verbosity
if obj.verbose
    fprintf('Trial %d; Freq [%2.2f, %2.2f Hz]...', ...
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
        stopTime = tic() + obj.interStimulusIntervalSecs*1e9;
        obj.CombiLEDObj.setContrast(intervalParams(ii,1));
        obj.CombiLEDObj.setFrequency(intervalParams(ii,2));
        obj.CombiLEDObj.setPhaseOffset(intervalParams(ii,3));
        obj.waitUntil(stopTime);

        % Present the stimulus. If it is the first interval, wait the
        % entire stimulusDuration. If it is the second interval. just wait
        % half of the stimulus and then move on to the response, thus
        % allowing the subject to respond during the second stimulus.
        if ii == 1
            stopTime = tic() + obj.stimulusDurationSecs*1e9 + obj.interStimulusIntervalSecs*1e9;
        else
            stopTime = tic() + 0.5*obj.stimulusDurationSecs*1e9;
        end
        obj.CombiLEDObj.startModulation;
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

    stillWaiting = true;
    while stillWaiting
        if cputime() > (lastRefreshTime + testRefreshIntervalSecs)
            drawnow
            switch currKeyPress
                case {'1'}
                    intervalChoice = 1;
                case {'2'}
                    intervalChoice = 2;
                    stillWaiting = false;
            end

            % Clear the keypress
            currKeyPress = '';

        end
    end
end

% Start the response interval
    [intervalChoice, responseTimeSecs] = obj.getResponse;
    % Make sure the stimulus has stopped
    obj.CombiLEDObj.stopModulation;
else
    [intervalChoice, responseTimeSecs] = obj.getSimulatedResponse(qpStimParam,testInterval);

% Determine if the subject has selected the correct interval and handle
% audio feedback
if ~isempty(intervalChoice)
    validResponse = true;
    if testInterval==intervalChoice
        % Correct
        outcome = 2;
        if obj.verbose
            fprintf('correct');
        end
        if ~simulateStimuli
            % We are not simulating, and the response was correct.
            % Regardless of whether we are giving feedback or not, we will
            % play the "correct" tone
            audioObjs.correct.play;
            obj.waitUntil(tic()+5e8);
        end
    else
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
                audioObjs.correct.play;
            end
            obj.waitUntil(tic()+5e8);
        end
    end
else
    outcome = nan;
    validResponse = false;
    if obj.verbose
        fprintf('no response');
    end
    if ~simulateStimuli
        % Buzz the bad trial
        audioObjs.bad.play;
        obj.waitUntil(tic()+3e9);
    end
end

% Finish the line of text output
if obj.verbose
    fprintf('\n');
end

% Update questData if a valid response
if validResponse
    % Update questData
    questData = qpUpdate(questData,qpStimParam,outcome);

    % Add in the phase and interval information
    questData.trialData(currTrialIdx).phase = testPhase;
    questData.trialData(currTrialIdx).testInterval = testInterval;
    questData.trialData(currTrialIdx).responseTimeSecs = responseTimeSecs;
else
    % Store a record of the invalid response
    questData.invalidResponseTrials(end+1) = currTrialIdx;
end

% Put staircaseData back into the obj
obj.questData = questData;

end