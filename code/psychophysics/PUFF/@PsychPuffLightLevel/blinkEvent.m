function [detected, responseTimeSecs] = blinkEvent(obj)

% Set the response interval
responseDurSecs = obj.blinkResponseIntervalSecs;

% Determine the identities of the responses
keyPress = KbName({'space','return'});
KbResponse = [];

% Enter a while loop
waitingForKey = true;
tic();
 while waitingForKey

    % Check keyboard:
    [isdown, ~, keycode]=KbCheck(-1);
    if isdown
        KbResponse = find(keycode);
        if any(keyPress==KbResponse)
            waitingForKey = false;
            responseTimeSecs = toc();
        end
    end

    % Check if we have run out of time
    if toc() > responseDurSecs
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