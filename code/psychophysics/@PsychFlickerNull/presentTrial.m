function presentTrial(obj)

% Increment the currTrialIdx
obj.currTrialIdx = obj.currTrialIdx + 1;

% Determine what we are simulating
simulateStimuli = obj.simulateStimuli;
simulateResponse = obj.simulateResponse;

% Prepare the sounds
Fs = 8192; % Sampling Frequency
dur = 0.1; % Duration in seconds
t  = linspace(0, dur, round(Fs*dur));
startSound = sin(2*pi*750*t);
audioObjs.start = audioplayer(startSound,Fs);

% Handle verbosity
if obj.verbose
    fprintf('Trial %d; adjust weight %2.2f\n', ...
        obj.currTrialIdx,obj.adjustWeight);
end

% Create a keypress response window
if ~simulateResponse
    [currKeyPress,S] = createResponseWindow();
end

% Present the stimuli
if ~simulateStimuli

    % Send the modulation direction to the CombiLED
    obj.CombiLEDObj.setSettings(obj.adjustedModResult);

    % Start the modulation and play a tone
    obj.CombiLEDObj.startModulation;
    audioObjs.start.play;
end

% Obtain a response
if ~simulateResponse
    validResponses = {'leftarrow','downarrow','rightarrow','uparrow','return'};
    keyPress = getResponse(currKeyPress,Inf,validResponses);
    close(S.fh);
else
    keyPress = '';
end

% Interpret the response
switch keyPress
    case {'leftarrow','downarrow'}
        choice = 'increase';
    case {'rightarrow','uparrow'}
        choice = 'decrease';
    otherwise
        % Subject did not press a valid key
        choice = 'done';
end

% Stop the modulation
if ~simulateStimuli
    obj.CombiLEDObj.stopModulation;
end

% Adjust the silencing weight
switch choice
    case 'increase'
        obj.adjustWeight = obj.adjustWeight + obj.adjustWeightDelta;
    case 'decrease'
        obj.adjustWeight = obj.adjustWeight - obj.adjustWeightDelta;
end

% Store the last response
obj.lastResponse = choice;

% create the adjusted modulation settings
obj.createAdjustedModResult();

end