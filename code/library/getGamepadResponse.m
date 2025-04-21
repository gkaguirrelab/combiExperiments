function [buttonPress, responseTimeSecs] = getGamepadResponse(responseDurSecs,validResponseSet)

% Define the return variables
responseTimeSecs = [];
buttonPress = [];

% Enter a while loop
waitingForButton = true;
intervalStartSecs = second(datetime(),'secondofday');
buttonCheckIdx = 1;

% Keep looping until a button is pressed
while waitingForButton

    % Check the next button
    buttonState = Gamepad('GetButton', 1, validResponseSet(buttonCheckIdx));

    if buttonState
        % A valid button was pressed
        waitingForButton = false;
    else
        % Increment the buttonCheckIdx
        buttonCheckIdx = buttonCheckIdx+1;
        if buttonCheckIdx > length(validResponseSet)
            buttonCheckIdx = 1;
        end
    end

    % Check if we have reached time out
    if second(datetime(),'secondofday') - intervalStartSecs > responseDurSecs
        return
    end

end
if buttonCheckIdx ==1
    buttonCheckIdx = length(validResponseSet);
else
    buttonCheckIdx = buttonCheckIdx - 1;
end

% Prepare the return variables
responseTimeSecs = second(datetime(),'secondofday') - intervalStartSecs;
buttonPress = validResponseSet(buttonCheckIdx);

end

