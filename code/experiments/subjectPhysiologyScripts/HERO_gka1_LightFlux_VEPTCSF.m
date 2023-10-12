% In these experiments we will work with this overall frequency set:

% For the LMS studies, we will operate in the high range. We will obtain
% CDTs for:
%   testFreqSetHz = [4,6,10,14,20,28,40]
%
% and then perform discrimination judgements with:
%   testFreqSetHz = [6,10,14,20,28]
%   refFreqSetHz = [4, 5, 6, 8, 10, 12, 14, 16, 20, 24, 28, 32, 40];

% prepare the params
subjectID = 'HERO_gka1';
modDirection = 'LightFlux';
observerAgeInYears = 53;
pupilDiameterMm = wy_getPupilSize(observerAgeInYears, 220, 30, 1, 'Unified');

% run the experiment
runVEPTCSFExperiment(subjectID,modDirection,...
    'observerAgeInYears',observerAgeInYears,...
    'pupilDiameterMm',pupilDiameterMm);
