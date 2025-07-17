function [intervalChoice, responseTimeSecs] = getResponse(obj)

% Set the response interval
responseDurMicroSecs = Inf;

% Determine the identities of the responses
keyPress1 = [30, 89];
keyPress2 = [31, 90];
KbResponse = [];

% Silence command window key press echoes
ListenChar(2)

% Enter a while loop
waitingForKey = true;
intervalStart = tic();
while waitingForKey

    % Check keyboard:
    [isdown, ~, keycode]=KbCheck(-1);
    if isdown
        KbResponse = find(keycode);
        if any([keyPress1, keyPress2]==KbResponse)
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
    intervalChoice = [];
else
    switch KbResponse
        case num2cell(keyPress1)
            intervalChoice = 1;
        case num2cell(keyPress2)
            intervalChoice = 2;
        otherwise
            % Subject did not press a valid key
            intervalChoice = [];
    end
end

% Restore command window key press echoes
ListenChar(0)

end