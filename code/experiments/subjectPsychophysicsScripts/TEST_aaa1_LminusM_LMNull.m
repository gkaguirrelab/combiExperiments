% In these experiments we will work with this overall frequency set:
%   freq = [1, 2, 3, 4, 5, 6, 8, 10, 12, 14, 16, 20, 24, 28, 32, 40];
%
% For the L-M studies, we will operate in the low range. We will obtain
% CDTs for:
%   testFreqSetHz = [1,3,5,8,12,16,24]
%
% and then perform discrimination judgements with:
%   testFreqSetHz = [3,5,8,12,16]
%   refFreqSetHz = [1, 2, 3, 4, 5, 6, 8, 10, 12, 14, 16, 20, 24];
%

% prepare the params
subjectID = 'TEST_aaa1';
observerAgeInYears = 53;
pupilDiameterMm = wy_getPupilSize(observerAgeInYears, 220, 30, 1, 'Unified');
stimContrast = 0.15;

% run the experiment
runFlickerNullExperiment(subjectID,'LminusM_wide','LplusM_wide',...
    'observerAgeInYears',observerAgeInYears,...
    'simulateStimuli',true,'simulateResponse',true,...
    'pupilDiameterMm',pupilDiameterMm,...
    'stimContrast',stimContrast);
