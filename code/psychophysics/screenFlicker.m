% Set up some game pad values. Axis values given as a 16 bit signed integer
gamepadIndex = 1; axisIdx = 4; buttonIdx = 3;
axisMaxVal = 32768;

flickerFreqHz = 10; 

% Initialize the gamepad
Gamepad('Unplug');

% Create a figure
figHandle = figure();
figuresize(400,400,'pt')

% Create an image
im = zeros(400,400);
colormap('gray');
imHandle = image(im);
axis off
drawnow

% Enter a loop in which we interrogate the game pad every 100 msecs and
% adjust the frequency based upon the vertical position of the left thumb
% joystick. Continue to adjust until a press of the red button is detected.
ticTimeSecs = 0.01;
notDone = true;
tic;
startTime = toc;
lastUpdate = startTime;
while notDone
    nowTime = toc;
    if (nowTime-lastUpdate) > ticTimeSecs
        if Gamepad('GetButton', gamepadIndex, buttonIdx)
            % The button was pressed, so we are done
            notDone = false;
        else
            % Update the flicker display
            imVal = round(255*(1+sin((nowTime-startTime)*flickerFreqHz*2*pi))/2);
            imHandle.CData(:)=imVal;
            drawnow

            % Update the timer
            lastUpdate=toc;
        end
    end
end

close(figHandle);
