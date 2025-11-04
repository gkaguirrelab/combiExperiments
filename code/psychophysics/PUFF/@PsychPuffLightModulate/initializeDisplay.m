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
%    obj.LightObj.setBimodal();
%    obj.LightObj.setWaveformIndex(1); % sinusoid
    obj.LightObj.setContrast(obj.lightModContrast);
    obj.LightObj.setFrequency(obj.lightModFreqHz);
    obj.LightObj.setDuration(obj.lightModDurSecs);
    obj.LightObj.setPhaseOffset(obj.lightModPhase);
    obj.LightObj.setRampIndex(0); % no ramp

end

end