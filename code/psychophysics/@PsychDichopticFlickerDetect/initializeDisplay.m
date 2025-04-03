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

   % Check that the minimum modulation contrast specified in
   % testLogContrastSet does not encounter quantization errors for the
   % spectral modulation that is loaded into each combiLED. We use the
   % passed parameter "bitThresh" to determine how much quantization we
   % will accept. The default is two bits, meaning that our "sinusoid"
   % modulation must contain at least four discrete levels.
   minContrast1 = obj.relativePhotoContrastCorrection(1) * 10^min(obj.testLogContrastSet);
   quantizeErrorFlags = ...
       obj.CombiLEDObj1.checkForQuantizationError(minContrast1,obj.bitThresh);
   assert(~any(quantizeErrorFlags));

   minContrast2 = obj.relativePhotoContrastCorrection(2) * 10^min(obj.testLogContrastSet);
   quantizeErrorFlags = ...
       obj.CombiLEDObj2.checkForQuantizationError(minContrast2,obj.bitThresh);
   assert(~any(quantizeErrorFlags));

end

end