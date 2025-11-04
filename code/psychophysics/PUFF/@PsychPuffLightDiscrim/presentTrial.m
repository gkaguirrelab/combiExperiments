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

% The calling function sets the refPuffPSI, the duration of each puff, and
% the inter-trial interval range
refPuffPSI = obj.refPuffPSI;
puffDurSecs = obj.puffDurSecs;

% Get the stimParam to use for this trial.
testParam = qpQuery(questData);

% The difference between the reference and test frequency is given by the
% testParam, which is in units of decibels.
testPuffPSI = refPuffPSI * db2pow(testParam);

% If the testPuffPSI is great than the maximum allowed PSI value, adjust
% the stimParam to stay within the max allowed
if testPuffPSI > obj.maxAllowedPressurePSI
    maxStimParam = pow2db(obj.maxAllowedPressurePSI / refPuffPSI);
    [~,idx]=find(obj.stimParamsDomainList<maxStimParam,1,"last");
    testParam = obj.stimParamsDomainList(idx);
    testPuffPSI = refPuffPSI * db2pow(testParam);
    warning('test param reduced to be within allowed safety range');
end

% Assemble the param sets
testParams = [testPuffPSI,puffDurSecs];
refParams = [refPuffPSI,puffDurSecs];

% Randomly assign the stimuli the first or second interval
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
        error('Not a valid interval')
end

% Note which interval contains the more intense stimulus, which is used for
% feedback
[~,moreIntenseInterval] = max(intervalParams(:,1));

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

% Handle verbosity
if obj.verbose
    fprintf('Trial %d; Puff duration [%2.2f]; Pressure PSI [%2.2f, %2.2f PSI]...', ...
        currTrialIdx,obj.puffDurSecs,intervalParams(1,1),intervalParams(2,1));
end

% Define this variable in case we are in simulation mode
irVidTrialLabel = [];

% Present the stimuli
if ~simulateStimuli

    % Play the ready sound
    audioObjs.ready.play

    % Prepare the puff for the first interval
    preparePuff(obj,intervalParams(1,1),obj.puffDurSecs)

    % Define a camera recording time, which includes:
    % - 2 second before the first puff (this gives time for the puff
    %   pressure to adjust)
    % - the inter-stimulus-interval
    % - 1 second after the second air puff
    camRecordTimeSecs = 2 + obj.isiSecs + 1;

    % Define an overall minimum end time for the trial, which is the camera
    % record time plus the camera clean up time
    totalTrialTime = camRecordTimeSecs + obj.cameraCleanupDurSecs;
    overallStopTimeSecs = cputime() + totalTrialTime;

    % Start the camera recording
    obj.irCameraObj.durationSecs = camRecordTimeSecs;
    irVidTrialLabel = sprintf([obj.trialLabel '_trial-%03d'],currTrialIdx);
    obj.irCameraObj.prepareToRecord(irVidTrialLabel);
    obj.irCameraObj.startRecording(irVidTrialLabel);

    % Wait two seconds before the first puff
    stopTimeSeconds = cputime() + 2;
    obj.waitUntil(stopTimeSeconds);

    % Play the first puff sound, and pause briefly to let it get started
    audioObjs.low.play;
    pause(0.1);

    % Simultaneous, bilateral puff
    obj.AirPuffObj.triggerPuff('ALL');

    % Prepare the puff for the second interval
    preparePuff(obj,intervalParams(2,1),obj.puffDurSecs)

    % Wait for the ISI
    stopTimeSeconds = cputime() + obj.isiSecs;
    obj.waitUntil(stopTimeSeconds);

    % Play the second puff tone, and pause briefly to let it get started
    audioObjs.mid.play;
    pause(0.1);

    % Simultaneous, bilateral puff
    obj.AirPuffObj.triggerPuff('ALL');

end

% Re-express the testParam as the dB difference between the second and
% first interval; this is how we will think about the outcome
testParam = pow2db(intervalParams(2,1)/intervalParams(1,1));

% Start the response interval
if ~simulateResponse
    FlushEvents
    [intervalChoice, responseTimeSecs] = obj.getResponse();
else
    intervalChoice = obj.getSimulatedResponse(testParam);
    responseTimeSecs = nan;
end

% The outcome is simply the interval that has been selected
outcome = intervalChoice;

% Determine if the subject has selected the more intense interval and
% handle audio feedback. Make the correct noise regardless of the response
% when the two stimuli were identical.
if intervalChoice==moreIntenseInterval || testParam == 0
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
        obj.waitUntil(cputime()+1.0);
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
            audioObjs.mid.play;
        end
        obj.waitUntil(cputime()+1.0);
    end
end

% Wait until the total trial time has elapsed, or we have finished the
% minimum iti, whichever comes later. Also make sure that the recording has
% finished
if ~simulateStimuli

    % Define the stop time
    stopTimeSeconds = max([...
        overallStopTimeSecs, ...
        cputime() + obj.minItiSecs]);

    % Wait until the video recording file has closed
    obj.irCameraObj.checkFileClosed;

    % Keep waiting until we are done
    obj.waitUntil(stopTimeSeconds);

end

% Finish the line of text output
if obj.verbose
    fprintf('\n');
end

% Update questData
questData = qpUpdate(questData,testParam,outcome);

% Add in the stimulus information
questData.trialData(currTrialIdx).testParam = testParam;
questData.trialData(currTrialIdx).testInterval = testInterval;
questData.trialData(currTrialIdx).moreIntenseInterval = moreIntenseInterval;
questData.trialData(currTrialIdx).intervalChoice = intervalChoice;
questData.trialData(currTrialIdx).responseTimeSecs = responseTimeSecs;
questData.trialData(currTrialIdx).correct = correct;
questData.trialData(currTrialIdx).irVidTrialLabel = irVidTrialLabel;

% Put questData back into the obj
obj.questData = questData;

end



%% LOCAL FUNCTION
function preparePuff(obj,puffPSI,puffDurSecs)

% Store the last stimulus so we don't need to change it
persistent lastPuffPSI
persistent lastPuffDurSecs

if isempty(lastPuffPSI) % Check if it's the first call
    lastPuffPSI = -1;
    lastPuffDurSecs = -1;
end

% Store the warning state; turn off an occasional serial port warning
warnState = warning();
warning('off', 'serialport:serialport:ReadlineWarning');

% Check that the max required pressure is within the safety range
if puffPSI > obj.maxAllowedPressurePSI
    error('Requested puff pressure exceeds the safety limit');
end

% Check that the PSI * stimulus duration is not greater than
% maxAllowedRefPSIPerSec
if puffPSI*puffDurSecs > obj.maxAllowedRefPSIPerSec
    error('The PSI * duration of the stimulus exceeds the safety limit');
end

% Set the duration
if puffDurSecs ~=lastPuffDurSecs
    obj.AirPuffObj.setDuration('L',puffDurSecs*1000);
    obj.AirPuffObj.setDuration('R',puffDurSecs*1000);
end

% Set the pressures
if puffPSI ~=lastPuffPSI
    obj.AirPuffObj.setPressure('L',puffPSI);
    obj.AirPuffObj.setPressure('R',puffPSI);
end

% Store these stimuli
lastPuffDurSecs = puffDurSecs;
lastPuffPSI = puffPSI;

% Restore the warning state
warning(warnState);

end