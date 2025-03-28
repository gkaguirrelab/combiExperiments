function initializeDisplay(obj)

if isempty(obj.CombiLEDObj1) && isempty(obj.CombiLEDObj2) && ~obj.simulateStimuli
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

    obj.CombiLEDObj1.setSettings(obj.modResult1);    
    obj.CombiLEDObj1.setDuration(stimulusDurationSecs);
    obj.CombiLEDObj1.setWaveformIndex(1); % sinusoidal flicker

    obj.CombiLEDObj2.setSettings(obj.modResult2);    
    obj.CombiLEDObj2.setDuration(stimulusDurationSecs);
    obj.CombiLEDObj2.setWaveformIndex(1); % sinusoidal flicker
    
    % Subject the stimulus onset and offset to a half-cosine ramp
   obj.CombiLEDObj1.setAMIndex(2); % half-cosine windowing
   obj.CombiLEDObj1.setAMFrequency(1/stimulusDurationSecs);
   obj.CombiLEDObj1.setAMValues([0.25,0]); % 0.25 second half-cosine on; second value unused

   obj.CombiLEDObj2.setAMIndex(2); % half-cosine windowing
   obj.CombiLEDObj2.setAMFrequency(1/stimulusDurationSecs);
   obj.CombiLEDObj2.setAMValues([0.25,0]); % 0.25 second half-cosine on; second value unused

end

end