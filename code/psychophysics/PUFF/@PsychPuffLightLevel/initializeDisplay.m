function initializeDisplay(obj)

if isempty(obj.LightObj) && ~obj.simulateStimuli
    if obj.verbose
        fprintf('LightObj is empty; update this property and call the initializeDisplay method');
    end
end

% Ensure that the CombiLED is configured to present our stimuli
% properly (if we are not simulating the stimuli)
if ~obj.simulateStimuli

    % Alert the user
    if obj.verbose
        fprintf('Initializing CombiLEDObj\n')
    end

    obj.LightObj.setSettings(obj.modResult);
    obj.LightObj.setUnimodal();
    obj.LightObj.setWaveformIndex(2); % square-wave
    obj.LightObj.setFrequency(1/(2*obj.lightPulseDurSecs));
    obj.LightObj.setDuration(obj.lightPulseDurSecs);
    obj.LightObj.setPhaseOffset(pi);
    obj.LightObj.setRampIndex(1); % half-cosine windowing
    obj.LightObj.setRampDuration(2);
    obj.LightObj.setContrast(1);

end

end