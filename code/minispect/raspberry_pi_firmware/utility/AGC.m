function retval = AGC(s, gain, exposure, speedSetting)

    % Set the properties of the gain and exposure
    gainRange = [1 10];
    exposureRange = [37,floor(1e6/206.65)];
    signalTarget = 127;
    signalRange = [0,255];

    % Calculate the adjustment
    correction = 1+(signalTarget-s)/signalTarget;

    % Set the speed
    speed = speedSetting;

    % Move quickly if we are pegged at the signal range
    if s == signalRange(1) || s == signalRange(2)
        speed = speedSetting^2;
    end

    % Move quickly if we are close to the destination
    if abs(correction - 1)<0.25
        speed = speedSetting^2;
    end

    % Correct the correction
    correction = 1 + ((1-speed) * (correction-1));

    % If correction > 1, it means we need to turn up gain or exposure.
    if correction > 1
        % First choice is to turn up exposure
        if exposure < exposureRange(2)
            exposure = exposure * correction;
            exposure = min([exposure,exposureRange(2)]);
            exposure = max([exposure,exposureRange(1)]);
        else
            gain = gain * correction;
            gain = min([gain,gainRange(2)]);
            gain = max([gain,gainRange(1)]);
        end
    end

    % If correction < 1, it means we need to turn down gain or exposure.
    if correction < 1
        % First choice is to turn down gain
        if gain > gainRange(1)
            gain = gain * correction;
            gain = min([gain,gainRange(2)]);
            gain = max([gain,gainRange(1)]);
        else
            exposure = exposure * correction;
            exposure = min([exposure,exposureRange(2)]);
            exposure = max([exposure,exposureRange(1)]);
        end
    end

    retval.adjusted_gain = gain ; 
    retval.adjusted_exposure = exposure; 


end