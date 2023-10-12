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

    obj.CombiLEDObj.setBackground(obj.modResult.settingsBackground);
    obj.CombiLEDObj.setDuration(obj.pulseDurSecs);
    obj.CombiLEDObj.setWaveformIndex(1); % sinusoidal flicker
    obj.CombiLEDObj.setFrequency(obj.stimFreqHz);
    obj.CombiLEDObj.setAMIndex(2); % half-cosine ramped
    obj.CombiLEDObj.setAMFrequency(1/(2*obj.pulseDurSecs));
    obj.CombiLEDObj.setAMPhase(0);
    obj.CombiLEDObj.setAMValues([obj.halfCosineRampDurSecs, 0]);
    obj.CombiLEDObj.setDuration(obj.pulseDurSecs)

end

end