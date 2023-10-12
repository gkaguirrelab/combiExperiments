function coneVec = actLumusToCones(weightVec)
% Convert an n x 9 matrix of actLumus measurements to an n x 3 matrix of
% relative lms cone weights. This is all quite crude at the moment.

% Get the actLumus weighted spectral sensitivity functions
S = [380     2   201];
T_actLumus = returnActLumusSpectralSensitivity(S);

% Get the sensitivities for the foveal cone classes
fieldSizeDegrees = 30;
observerAgeInYears = 30;
pupilDiameterMm = 2;
T_receptors = GetHumanPhotoreceptorSS(S, ...
    {'LConeTabulatedAbsorbance2Deg', ...
    'MConeTabulatedAbsorbance2Deg', ...
    'SConeTabulatedAbsorbance2Deg'}, ...
    fieldSizeDegrees, observerAgeInYears, pupilDiameterMm, [], [], [], []);

% Create the spectrum implied by the rgb camera weights, and then project
% that on the receptors
coneVec = (T_receptors*(weightVec*T_actLumus)')';

end