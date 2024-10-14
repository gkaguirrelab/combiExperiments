function modulateCombiLED(frequency, cal_path)
% Modulate the combiLED indefinitely at a desired frequency (hz)
%
% Syntax:
%    modulateCombiLED(frequency, cal_path)
%
% Description:
%   Set the CombiLED to modulate indefinitely at a given frequency.
%   The CombiLED is initialized with the cal_path calibration file. 
%
% Inputs:
%   frequency             - Double. Represents the frequency at which to modulate
%
%   cal_path              - String. Represents the path to the light source
%                           calibration file.      
% Outputs:
%   None
%
% Examples:
%{
    [~, calFileName, calDir] = selectCal();
    cal_path = fullfile(calDir,calFileName);
    frequency = 5; 
    modulateCombiLED(frequency, cal_path);
%}

    % Validate arguments
    arguments
        frequency (1,1) {mustBeNumeric}
        cal_path (1,:) {mustBeText}
    end
    
    % Load in the calibration file for the CombiLED
    load(cal_path,'cals');
    cal = cals{end};

    % Initialize the combiLED
    disp('Opening connection to CombiLED...')
    CL = CombiLEDcontrol(); % Initialize CombiLED Object
    CL.setGamma(cal.processedData.gammaTable);  % Update the combiLED's gamma table

    % Collect information to compose flicker profile
    observerAgeInYears = 30;
    pupilDiameterMm = 3;
    photoreceptors = photoreceptorDictionaryHuman('observerAgeInYears',observerAgeInYears,'pupilDiameterMm',pupilDiameterMm);

    % Compose flicker profile
    modResult = designModulation('LightFlux',photoreceptors,cal);
    CL.setSettings(modResult);
    CL.setWaveformIndex(1);
    CL.setContrast(0.5);

    % Set the CL flicker to desired frequency
    CL.setFrequency(frequency);

    % Start flickering 
    disp('Beginning modulation...')
    CL.startModulation();

    % Pause while desired flicker
    disp('Press any key to stop modulation.')
    pause()
    
    % Close connection to the combiLED
    CL.serialClose();


end