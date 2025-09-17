function [detected, responseTimeSecs] = blinkEvent(obj)

% Set the response interval
responseDurMicroSecs = obj.blinkResponseIntervalSecs * 1e6;

% Determine the identities of the responses
keyPress = KbName({'spacebar','return'});
KbResponse = [];

% Enter a while loop
waitingForKey = true;
intervalStart = tic();
while waitingForKey

    % Check keyboard:
    [isdown, ~, keycode]=KbCheck(-1);
    if isdown
        KbResponse = find(keycode);
        if any(keyPress==KbResponse)
            waitingForKey = false;
            responseTimeSecs = double(tic()-intervalStart)/1e9;
        end
    end

    % Check if we have run out of time
    if (tic()-intervalStart) > responseDurMicroSecs
        waitingForKey = false;
        responseTimeSecs = nan;
    end

end

% Interpret the response
if isempty(KbResponse)
    detected = false;
else
    detected = true;
end

end