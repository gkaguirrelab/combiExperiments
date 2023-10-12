% Demo gamepad control of flicker frequency

% Define a starting frequency and the desired contrast of the modulation
contrast = 0.5;
freqHz = 16;
freqHzLowBound = 4;
freqHzHighBound = 64;

% Set up some game pad values. Axis values given as a 16 bit signed integer
gamepadIndex = 1; axisIdx = 4; buttonIdx = 3;
axisMaxVal = 32768;

% The adjustment value. This maps relative axis position to the
% proportional change in flicker frequqency at each update cycle.
adjVal = 1.1;

% Initialize the gamepad
Gamepad('Unplug');

% Connect to the CombiLED
obj = CombiLEDcontrol();

% Define a modulation
photoreceptors = photoreceptorDictionary();
modResult = designModulation('LightFlux',photoreceptors);

% Send the modulation properties to the CombiLED
obj.setSettings(modResult);
obj.setBackground(modResult.settingsBackground);
obj.setWaveformIndex(1);
obj.setFrequency(freqHz);
obj.setContrast(contrast);

% Start the modulation
obj.startModulation;

% Enter a loop in which we interrogate the game pad every 100 msecs and
% adjust the frequency based upon the vertical position of the left thumb
% joystick. Continue to adjust until a press of the red button is detected.
ticTimeSecs = 0.2;
notDone = true;
tic;
while notDone
    if toc > ticTimeSecs
        if Gamepad('GetButton', gamepadIndex, buttonIdx)
            % The button was pressed, so we are done
            notDone = false;
        else
            % Get the axis position.
            axisPos = Gamepad('GetAxis', gamepadIndex, axisIdx) / axisMaxVal;
            % Change the -1 to 1 axis position to be between 1 and adjVal,
            % where 1 is no change in frequency, and adjVal is the
            % adjustment
            axisSign = sign(axisPos);
            freqScale = 1 + ((adjVal - 1) * abs(axisPos));
            if axisSign > 0
                freqScale = 1 / freqScale;
            end
            % Apply the change in frequency
            freqHz = freqHz * freqScale;
            % Keep the frequency in bounds
            freqHz = max([freqHz freqHzLowBound]);
            freqHz = min([freqHz freqHzHighBound]);
            % Send the updated frequency to the CombiLED
            obj.setRunFrequency(freqHz);
            % Update the timer
            tic
        end
    end
end

% Clean up
obj.stopModulation;
obj.goDark;
obj.serialClose;
close all
clear