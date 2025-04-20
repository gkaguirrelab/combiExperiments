
function [keyPress, responseTimeSecs] = getKeyboardResponse(currKeyPress,responseDurSecs,validResponseSet)

% Initialize the retun values
keyPress = '';
responseTimeSecs = nan;

% Enter a while loop
waitingForKey = true;
intervalStartSecs = second(datetime(),'secondofday');
while waitingForKey

    % Refresh the response window object
    drawnow

    % Check if an acceptable key has been pressed
    switch currKeyPress
        case validResponseSet
            waitingForKey = false;
            keyPress = currKeyPress;
            responseTimeSecs = second(datetime(),'secondofday') - intervalStartSecs;
    end

    % Clear the keypress
    currKeyPress = '';

    % Check if the response interval has elapsed
    if second(datetime(),'secondofday')>(intervalStartSecs+responseDurSecs)
        waitingForKey = false;
    end

end

end
