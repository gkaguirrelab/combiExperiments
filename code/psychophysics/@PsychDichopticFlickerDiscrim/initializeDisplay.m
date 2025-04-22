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

        % Duration. We make side 2 shorter by combiLEDStartTimeSecs to
        % account for the time it takes to tell the first combiLED to start
        % the modulation
        thisDuration = obj.stimDurSecs - (side-1) * obj.combiLEDStartTimeSecs;
        obj.CombiLEDObjArr{side}.setDuration(thisDuration);

        % Subject the stimulus onset and offset to a half-cosine ramp
        obj.CombiLEDObjArr{side}.setAMIndex(2); % half-cosine windowing
        obj.CombiLEDObjArr{side}.setAMFrequency(1/obj.stimDurSecs);
        obj.CombiLEDObjArr{side}.setAMValues([0.1,0]); % 0.1 second half-cosine on; second value unused

    end

end

end