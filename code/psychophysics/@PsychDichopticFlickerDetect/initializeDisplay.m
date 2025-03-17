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

    obj.CombiLEDObjA.setSettings(obj.modResultA);    
    obj.CombiLEDObjA.setDuration(obj.stimulusDurationSecs);
    obj.CombiLEDObjA.setWaveformIndex(1); % sinusoidal flicker

    obj.CombiLEDObjB.setSettings(obj.modResultB);    
    obj.CombiLEDObjB.setDuration(obj.stimulusDurationSecs);
    obj.CombiLEDObjB.setWaveformIndex(1); % sinusoidal flicker
    
    % Subject the stimulus onset and offset to a half-cosine ramp
    obj.CombiLEDObjA.setAMIndex(2); % half-cosine windowing
    obj.CombiLEDObjA.setAMFrequency(1/obj.stimulusDurationSecs);
    obj.CombiLEDObjA.setAMValues([0.25,0]); % 0.25 second half-cosine on; second value unused

    obj.CombiLEDObjB.setAMIndex(2); % half-cosine windowing
    obj.CombiLEDObjB.setAMFrequency(1/obj.stimulusDurationSecs);
    obj.CombiLEDObjB.setAMValues([0.25,0]); % 0.25 second half-cosine on; second value unused

end

end