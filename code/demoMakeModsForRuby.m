
% The directions and ND settings we will use
NDlabels = {'0x5','3x5'};
directions = {'LminusM_wide','LightFlux'};

% The background XY chromaticity we will target
xyTarget = [0.453178;0.348074];

% How much headroom we want
primaryHeadRoom = 0.1;

% Define and load the observer photoreceptors
observerAgeInYears = 53;
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
    cal = baseCal;
    for ii = 1:size(cal.processedData.P_device,2)
        cal.processedData.P_device(:,ii) = ...
            cal.processedData.P_device(:,ii) .* transmittance;
    end
    cal.processedData.P_ambient = cal.processedData.P_ambient .* ...
        transmittance;

    whichDirection = 'LminusM_wide';

    modResult{nn,1} = designModulation(whichDirection,photoreceptors,cal,...
        'primaryHeadRoom',primaryHeadRoom,'contrastMatchConstraint',3,...
        'xyTarget',xyTarget,'searchBackground',true);
    plotModResult(modResult{nn,1});

    whichDirection = 'LightFlux_reduced';
    backgroundPrimary = modResult{nn,1}.settingsBackground;

    modResult{nn,2} = designModulation(whichDirection,photoreceptors,cal,...
        'primaryHeadRoom',primaryHeadRoom,'contrastMatchConstraint',3,...
        'backgroundPrimary',backgroundPrimary,'searchBackground',true,...
        'xyTol',0,'xyTolWeight',1e5);
    plotModResult(modResult{nn,2});

end
