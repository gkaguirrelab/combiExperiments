function initializeDisplay(obj)

if isempty(obj.CombiLEDObjC) && isempty(obj.CombiLEDObjD) && ~obj.simulateStimuli
    if obj.verbose
        fprintf('One or both of the CombiLEDObjs is empty; update this property and call the initializeDisplay method');
    end
end

% Ensure that the CombiLEDs are configured to present our stimuli
% properly (if we are not simulating the stimuli)
if ~obj.simulateStimuli

    % Set an arbitrarily long duration for stimulus presentation. This is
    % because we allow the observer response to terminate the trial.
    stimulusDurationSecs = 30;

    % Alert the user
    if obj.verbose
        fprintf('Initializing CombiLEDObj\n')
    end

    obj.CombiLEDObjC.setSettings(obj.modResultC);    
    obj.CombiLEDObjC.setDuration(stimulusDurationSecs);
    obj.CombiLEDObjC.setWaveformIndex(1); % sinusoidal flicker

    obj.CombiLEDObjD.setSettings(obj.modResultD);    
    obj.CombiLEDObjD.setDuration(stimulusDurationSecs);
    obj.CombiLEDObjD.setWaveformIndex(1); % sinusoidal flicker
    
    % Subject the stimulus onset and offset to a half-cosine ramp
   obj.CombiLEDObjC.setAMIndex(2); % half-cosine windowing
   obj.CombiLEDObjC.setAMFrequency(1/stimulusDurationSecs);
   obj.CombiLEDObjC.setAMValues([0.25,0]); % 0.25 second half-cosine on; second value unused

   obj.CombiLEDObjD.setAMIndex(2); % half-cosine windowing
   obj.CombiLEDObjD.setAMFrequency(1/stimulusDurationSecs);
   obj.CombiLEDObjD.setAMValues([0.25,0]); % 0.25 second half-cosine on; second value unused

end

end