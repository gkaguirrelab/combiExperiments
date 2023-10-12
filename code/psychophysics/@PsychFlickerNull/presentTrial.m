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

% Get the next stimulus setting
qpStimParams = qpQuery(questData);
adjustWeight = qpStimParams(1);

% Obtain adjusted modulation settings
modResultNew = obj.returnAdjustedModResult(adjustWeight);


% modResultNew = obj.modResult;
% 
% % Adjust the high or low settings
% if obj.adjustHighSettings
%     settingsHigh = obj.modResult.settingsHigh + ...
%         adjustWeight * obj.adjustSettingsVec;
%     settingsLow = obj.modResult.settingsLow;
% else
%     settingsHigh = obj.modResult.settingsHigh;
%     settingsLow = obj.modResult.settingsLow + ...
%         adjustWeight * obj.adjustSettingsVec;
% end
% 
% % Re-center the modulation
% adj = obj.modResult.settingsBackground - (settingsHigh+settingsLow)/2;
% modResultNew.settingsHigh = settingsHigh + adj;
% modResultNew.settingsLow = settingsLow + adj;

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
    testPhase = round(rand())*pi;
else
    testPhase = 0;
end

% Assemble the param sets
testParams = [obj.stimContrast,testPhase];
refParams = [0,0];

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

% Handle verbosity
if obj.verbose
    fprintf('Trial %d; adjust weight %2.2f...', ...
        currTrialIdx,adjustWeight);
end

% Present the stimuli
if ~simulateStimuli

    % Send the modulation direction to the CombiLED
    obj.CombiLEDObj.setSettings(modResultNew);

    % Alert the subject the trial is about to start
    audioObjs.ready.play;
    stopTime = tic() + 1e9;
    obj.waitUntil(stopTime);

    % Present the two intervals
    for ii=1:2

        % Prepare the stimulus
        stopTime = tic() + obj.interStimulusIntervalSecs*1e9;
        obj.CombiLEDObj.setContrast(intervalParams(ii,1));
        obj.CombiLEDObj.setPhaseOffset(intervalParams(ii,2));
        obj.waitUntil(stopTime);

        % Present the stimulus. If it is the first interval, wait the
        % entire stimulusDuration. If it is the second interval. just wait
        % half of the stimulus and then move on to the response, thus
        % allowing the subject to respond during the second stimulus.
        if ii == 1
            stopTime = tic() + obj.pulseDurSecs*1e9 + obj.interStimulusIntervalSecs*1e9;
        else
            stopTime = tic() + 0.5*obj.pulseDurSecs*1e9;
        end

        % Start the modulation and play a tone
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
    [intervalChoice, responseTimeSecs] = obj.getResponse;
    % Make sure the stimulus has stopped
    obj.CombiLEDObj.stopModulation;
else
    [intervalChoice, responseTimeSecs] = obj.getSimulatedResponse(qpStimParams,testInterval);
end

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
    questData = qpUpdate(questData,qpStimParams,outcome);

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