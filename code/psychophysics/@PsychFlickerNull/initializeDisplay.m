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

    obj.CombiLEDObj.setSettings(obj.adjustedModResult);
    obj.CombiLEDObj.setWaveformIndex(obj.stimWaveform); % square wave flicker
    obj.CombiLEDObj.setFrequency(obj.stimFreqHz);
    obj.CombiLEDObj.setContrast(obj.stimContrast);
end

end