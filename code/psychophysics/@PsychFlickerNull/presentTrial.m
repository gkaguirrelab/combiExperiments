function presentTrial(obj)

%% NEED TO UPDATE THIS TO ACHIEVE:
% - Each trial starts with a high positive or negative adjustment weight
% - The observer steadily reduces the absolute value of the adjustment weight
% until they end the trial because they have reached a minimum at which
% they can no longer see the stimulus
% - Store the final adjustment weight for the trial
% - Alternate between starting postive and negative across trials
% - Repeat as long as the calling function wants.

% Increment the currTrialIdx
obj.currTrialIdx = obj.currTrialIdx + 1;

% We alternate between the high and low adjustment start points
startHighFlag = mod(obj.currTrialIdx,2);

% Determine what we are simulating
simulateStimuli = obj.simulateStimuli;
simulateResponse = obj.simulateResponse;

% Prepare the sounds
Fs = 8192; % Sampling Frequency
dur = 0.1; % Duration in seconds
t  = linspace(0, dur, round(Fs*dur));
startSound = sin(2*pi*750*t);
audioObjs.start = audioplayer(startSound,Fs);

% Create a keypress response window
if ~simulateResponse
    [currKeyPress,S] = createResponseWindow();
end

% Set a starting adjustment weight
if startHighFlag
    adjustWeight = obj.maxAdjustWeight;
    adjustStep = -obj.adjustWeightDelta;
else
    adjustWeight = -obj.maxAdjustWeight;
    adjustStep = +obj.adjustWeightDelta;
end    

% Enter a stimulus adjustment loop
notDoneFlag = true;
while notDoneFlag

    % Handle verbosity
    if obj.verbose
        fprintf('Trial %d; adjust weight %2.2f\n', ...
            obj.currTrialIdx,adjustWeight);
    end

    % create the adjusted modulation settings
    adjModResult = obj.createAdjustedModResult(adjustWeight);

    % Update the settings and start the flicker
    if ~simulateStimuli

        % Send the modulation direction to the CombiLED
        obj.CombiLEDObj.setSettings(adjModResult);

        % Start the modulation and play a tone
        obj.CombiLEDObj.startModulation;
        audioObjs.start.play;
    end

    % Obtain a response
    if ~simulateResponse
        validResponses = {'uparrow','leftarrow','downarrow','rightarrow','return'};
        keyPress = getResponse(currKeyPress,Inf,validResponses);
    else
        keyPress = '';
    end

    % Interpret the response
    switch keyPress
        case {'rightarrow','downarrow'}
            choice = 'adjust';
        case {'uparrow','leftarrow'}
            choice = 'reverse';
        case {'return'}
            choice = 'done';
        otherwise
            % Subject did not press a valid key
            choice = 'done';
    end

    % Adjust the silencing weight
    
    switch choice
        case 'adjust'
            adjustWeight = adjustWeight + adjustStep;
        case 'reverse'
            adjustWeight = adjustWeight - adjustStep;
            notDoneFlag = false;
        case 'done'
            notDoneFlag = false;
    end

    % Check if we have not hit the adjustment max boundary
    if abs(adjustWeight) > obj.maxAdjustWeight
        % PLAY SOME ERROR SOUND HERE
        notDoneFlag = false;
    end

    % Stop the modulation
    if ~simulateStimuli
        obj.CombiLEDObj.stopModulation;
    end

end

% Close the response window
if ~simulateResponse
    close(S.fh);
end

% Store the trial outcome
obj.trialData(obj.currTrialIdx).startHighFlag = startHighFlag;
obj.trialData(obj.currTrialIdx).adjustWeight = adjustWeight;


end