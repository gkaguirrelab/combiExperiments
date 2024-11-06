function initializeDisplay(obj)

if isempty(obj.CombiLEDObj) && ~obj.simulateStimuli
    if obj.verbose
        fprintf('CombiLEDObj is empty; update this property and call the initializeDisplay method');
    end
end

% Ensure that the CombiLED is configured to present our stimuli
% properly (if we are not simulating the stimuli)
if ~obj.simulateStimuli

    % Alert the user
    if obj.verbose
        fprintf('Initializing CombiLEDObj\n')
    end

    obj.CombiLEDObj.setSettings(obj.modResult);    
    obj.CombiLEDObj.setDuration(obj.stimulusDurationSecs);
    obj.CombiLEDObj.setWaveformIndex(1); % sinusoidal flicker
    
end

end