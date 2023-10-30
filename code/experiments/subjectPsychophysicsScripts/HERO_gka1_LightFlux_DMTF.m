% Delayed match to frequency for light flux at a high contrast level

% prepare the params
subjectID = 'HERO_gka1';
modDirection = 'LightFlux';
refFreqRangeHz = [2 10];
contrastRelative = 0.5;
observerAgeInYears = 53;
pupilDiameterMm = wy_getPupilSize(observerAgeInYears, 220, 30, 1, 'Unified');

% run the experiment
runDelayedMatchExperiment(subjectID,modDirection,contrastRelative,...
    'observerAgeInYears',observerAgeInYears,...
    'pupilDiameterMm',pupilDiameterMm,...
    'refFreqRangeHz',refFreqRangeHz);
