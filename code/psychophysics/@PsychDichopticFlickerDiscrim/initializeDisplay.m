function initializeDisplay(obj)

if isempty(obj.CombiLEDObjA) && isempty(obj.CombiLEDObjB) && ~obj.simulateStimuli
    if obj.verbose
        fprintf('One or both of the CombiLEDObjs is empty; update this property and call the initializeDisplay method');
    end
end

% Ensure that the CombiLEDs are configured to present our stimuli
% properly (if we are not simulating the stimuli)
if ~obj.simulateStimuli

    % Alert the user
    if obj.verbose
        fprintf('Initializing CombiLEDObj\n')
    end

    obj.CombiLEDObjA.setSettings(obj.modResult);    
    obj.CombiLEDObjA.setDuration(obj.stimulusDurationSecs);
    obj.CombiLEDObjA.setWaveformIndex(1); % sinusoidal flicker

    obj.CombiLEDObjB.setSettings(obj.modResult);    
    obj.CombiLEDObjB.setDuration(obj.stimulusDurationSecs);
    obj.CombiLEDObjB.setWaveformIndex(1); % sinusoidal flicker
    
end

end