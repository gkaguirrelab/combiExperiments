
% Housekeeping
clear
close all
clc
rng(cputime); % Ensure that the attention events differ each time

% Flag to simulate the combiLED
simulateCombiLED = false;

% The name of the calibration file to use
calDir = fullfile(tbLocateToolbox('combiLEDToolbox'),'cal');
calName = 'CombiLED_shortLLG_cassetteND1_longRandomA_stubby7TEyePiece_ND0';
calPath = fullfile(calDir,calName);

% Load the cal
load(calPath,'cals');
cal = cals{end};

% Get observer properties
observerID = GetWithDefault('Subject ID','WSTE_0000');
observerAgeInYears = str2double(GetWithDefault('Age in years','39'));
pupilDiameterMm = str2double(GetWithDefault('Pupil diameter in mm','3'));

% Get the photoreceptor set for this observer
photoreceptors = photoreceptorDictionaryHuman('observerAgeInYears',observerAgeInYears,'pupilDiameterMm',pupilDiameterMm);

% Create the modulation
modResult = designModulation('LightFlux',photoreceptors,cal);

% The name of the directory in which to store the results files
dropboxBaseDir = getpref('combiExperiments','dropboxBaseDir');
sessionID = string(datetime('now','Format','yyyy-MM-dd'));
resultDir = fullfile(dropboxBaseDir,'WSTE_data','ampModPilot',observerID,sessionID);
mkdir(resultDir);

% Save the modResult
fileName = fullfile(resultDir,'modResult.mat');
save(fileName,"modResult");

% Define some experiment properties
attentionEventProbPerTrial = 0.33;
blinkDurSecs = 0.25;
attentionResponseDurSecs = 1.5;
validAttentionResponseSet = {'r','g','b','y'};
experimentStartKey = 't';
quitKey = 'q';
totalAcqDurSecs = 860;

% Set up the combiLED
if ~simulateCombiLED

    % Open a CombiLEDcontrol object
    obj = CombiLEDcontrol();

    % Set the CombiLED to be dark
    obj.goDark

    % Update the gamma table
    obj.setGamma(cal.processedData.gammaTable);

    % Send the modulation settings
    obj.setSettings(modResult);
    obj.setWaveformIndex(1);
    obj.setFrequency(16);
    obj.setContrast(1);
    obj.setAMIndex(1);
    obj.setAMFrequency(0.1);
    obj.setBlinkDuration(blinkDurSecs);

    % Go dark again
    obj.goDark

end

% Wait during the preliminary acquisitions and soak up any stray keystrokes
% (e.g., testing the button box; TRs produced by the field map acquisition)
fprintf('****************************************************\n')
fprintf('   Press return when prelim acquisitions are done\n')
fprintf('(button presses and TRs will be ignored untill then)\n')
input(': ','s');
fprintf('****************************************************\n')

% Create a keypress response window
[currKeyPress,S] = createResponseWindow();

notDone = true;
while notDone

    % Wait for a "t" stimulus to start the acquisition
    fprintf('Waiting for a TR trigger...')
    keyPress = getResponse(currKeyPress,Inf,{experimentStartKey,quitKey'});

    switch keyPress
        case 'q'
            notDone = false;
            fprintf('Quitting.\n')
            continue

        case 't'
            % Proceed
    end

    % Announce we are starting
    fprintf('starting acquisition...')

    % Get the start time
    acqStartTime = datetime();

    % Update the combiLED if we are not simulating
    if ~simulateCombiLED

        % Start the modulation
        obj.startModulation;

    end

    % Wait until we have reached our stop time
    while seconds(datetime() - acqStartTime) < totalAcqDurSecs
    end

    % Stop the modulation
    if ~simulateCombiLED; obj.stopModulation; obj.goDark; end

    % Report being done
    fprintf('done\n')

end

% Clean up combiLED
if ~simulateCombiLED; obj.serialClose; end

% Close the keypress window
close(S.fh);
