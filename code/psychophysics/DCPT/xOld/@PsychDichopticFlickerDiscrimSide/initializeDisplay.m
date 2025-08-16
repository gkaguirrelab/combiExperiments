function initializeDisplay(obj)

% Check that the CombiLED objects are both defined
if ~obj.simulateMode
    for side = 1:2
        if isempty(obj.CombiLEDObjArr{side})
            fprintf('One or both of the CombiLEDObjs is empty; update this property and call the initializeDisplay method\n');
        end
    end
end

% Ensure that the CombiLEDs are configured to present our stimuli
% properly (if we are not simulating the stimuli)
if ~obj.simulateMode

    % Alert the user
    if obj.verbose
        fprintf('Initializing CombiLEDObj\n')
    end

    for side = 1:2

        % Pass the modResult, and set to a sinusoidal flicker
        obj.CombiLEDObjArr{side}.setSettings(obj.modResultArr{side});
        obj.CombiLEDObjArr{side}.setWaveformIndex(1); % sinusoidal flicker

        % Duration.
        obj.CombiLEDObjArr{side}.setDuration(obj.stimDurSecs);

        % Subject the stimulus onset and offset to a half-cosine ramp
        obj.CombiLEDObjArr{side}.setRampIndex(1); % half-cosine windowing
        obj.CombiLEDObjArr{side}.setRampDuration(obj.rampDurSecs);

    end

end

end