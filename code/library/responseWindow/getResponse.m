
function [keyPress, responseTimeSecs] = getResponse(currKeyPress,responseDurSecs,validResponseSet)

% Initialize the retun values
keyPress = '';
responseTimeSecs = nan;

% Enter a while loop
waitingForKey = true;
intervalStartSecs = double(cputime());
while waitingForKey

    % Refresh the response window object
    drawnow

    % Check if an acceptable key has been pressed
    switch currKeyPress
        case validResponseSet
            waitingForKey = false;
            keyPress = currKeyPress;
            responseTimeSecs = double(cputime()) - intervalStartSecs;
    end

    % Clear the keypress
    currKeyPress = '';

    % Check if the response interval has elapsed
    if double(cputime())>(intervalStartSecs+responseDurSecs)
        waitingForKey = false;
    end

end

end
