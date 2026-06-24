% 1. Load the modResult file
%load('modResult_Mel.mat'); % or modResult_LightFlux.mat

% 2. Extract the wavelength sampling array (S) and background spectrum
S = modResult.meta.cal.rawData.S;
backspd = modResult.backgroundSPD;

% 3. Calculate the absolute illuminance of the baseline background
% (This function integrates the SPD against the photopic efficiency curve V_lambda)
backgroundLux = SToLux(backspd, S);

fprintf('===============================================\n');
fprintf('Baseline Background Illuminance: %2.2f Lux\n', backgroundLux);
fprintf('===============================================\n\n');

% 4. Calculate the Lux levels for the 5 Light Level Experiment conditions
% (Based on your script's logic where contrast levels scale up from the background)
contrastLevels = [0.0375, 0.075, 0.15, 0.30, 0.60];

fprintf('Light Level Experiment Condition Lux Values:\n');
for ii = 1:length(contrastLevels)
    % Reconstruct the positive-going step SPD exactly like your script does:
    % posspd = backspd + contrast * (positiveModulationSPD - backspd)
    conditionSPD = backspd + contrastLevels(ii) * (modResult.positiveModulationSPD - backspd);
    
    % Convert this condition's absolute SPD to Lux
    conditionLux = SPhToLux(conditionSPD, S);
    
    fprintf('  Condition %d (Contrast %0.4f): %2.2f Lux\n', ii, contrastLevels(ii), conditionLux);
end
fprintf('===============================================\n');