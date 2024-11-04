
% Housekeeping
close all
clear

% The directions and ND settings we will use
NDlabels = {'0x5','3x5'};
directions = {'LminusM_wide','LightFlux_reduced'};

% The background XY chromaticity we will target
xyTarget = [0.453178;0.348074];

% How much headroom we want. We need to enforce extra headroom on the 7th
% primary, as this one has a poorly behaved gamma function
primaryHeadRoom = [0.075,0.075,0.075,0.075,0.075,0.075,0.20,0.075];

% Define and load the observer photoreceptors
observerAgeInYears = 22;
pupilDiameterMm = 3;
photoreceptors = photoreceptorDictionaryHuman('observerAgeInYears',observerAgeInYears,'pupilDiameterMm',pupilDiameterMm);

% Load the base cal and the max (ND0) cal
baseCalName = 'CombiLED-B_shortLLG_classicEyePiece_irFilter_Cassette-ND0';
baseCal = loadCalByName(baseCalName);
maxSPDCalName = 'CombiLED-B_shortLLG_classicEyePiece_irFilter_Cassette-ND0_maxSpectrum';
maxSPDCal = loadCalByName(maxSPDCalName);

% Loop over the experiment sets
for nn = 1:length(NDlabels)

    % Obtain the transmittance for this ND filter setting
    targetSPDCalName = ['CombiLED-B_shortLLG_classicEyePiece_irFilter_Cassette-ND' NDlabels{nn} '_maxSpectrum'];
    targetSPDCal = loadCalByName(targetSPDCalName);
    transmittance = targetSPDCal.rawData.gammaCurveMeanMeasurements ./ maxSPDCal.rawData.gammaCurveMeanMeasurements;

    % Create this cal file
    cal{nn} = baseCal;
    for ii = 1:size(cal{nn}.processedData.P_device,2)
        cal{nn}.processedData.P_device(:,ii) = ...
            cal{nn}.processedData.P_device(:,ii) .* transmittance;
    end
    cal{nn}.processedData.P_ambient = cal{nn}.processedData.P_ambient .* ...
        transmittance;

    whichDirection = 'LminusM_wide';

    modResult{nn,1} = designModulation(whichDirection,photoreceptors,cal{nn},...
        'primaryHeadRoom',primaryHeadRoom,'contrastMatchConstraint',3,...
        'xyTarget',xyTarget,'searchBackground',true);
    plotModResult(modResult{nn,1});
    drawnow

    whichDirection = 'LightFlux';
    backgroundPrimary = modResult{nn,1}.settingsBackground;

    modResult{nn,2} = designModulation(whichDirection,photoreceptors,cal{nn},...
        'primaryHeadRoom',primaryHeadRoom,'backgroundPrimary',backgroundPrimary);
    plotModResult(modResult{nn,2});
    drawnow

end
