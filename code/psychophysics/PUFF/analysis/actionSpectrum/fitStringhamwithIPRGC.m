%% BADS Optimization & Comparison: Stringham (2°) vs. Empirical (10°)

% 1. Preference & Path Setup with Fallback
projectName = 'combiExperiments';
if ispref(projectName, 'projectBaseDir')
    ProjectBaseDir = getpref(projectName, 'projectBaseDir');
else
    scriptDir = fileparts(mfilename('fullpath'));
    ProjectBaseDir = scriptDir;
    while ~isempty(ProjectBaseDir) && ~exist(fullfile(ProjectBaseDir, 'code'), 'dir')
        parentDir = fileparts(ProjectBaseDir);
        if strcmp(parentDir, ProjectBaseDir), break; end
        ProjectBaseDir = parentDir;
    end
end
targetSubPath = fullfile('code', 'psychophysics', 'PUFF', 'analysis', ...
    'actionSpectrum', 'StringhamAvgPhotophobiaActionSpectrum.csv');
filePath = fullfile(ProjectBaseDir, targetSubPath);
if ~exist(filePath, 'file')
    filePath = which('StringhamAvgPhotophobiaActionSpectrum.csv');
    if isempty(filePath) && exist('StringhamAvgPhotophobiaActionSpectrum.csv', 'file')
        filePath = 'StringhamAvgPhotophobiaActionSpectrum.csv';
    end
end

% 2. Load Stringham Average Data
targetWl = (440:20:640)';
dataMatrix = readmatrix(filePath);
validY = dataMatrix(~isnan(dataMatrix(:, 2)), 2);
targetLogSens = validY(1:length(targetWl));

%% 3. Clean BADS Path Environment & Run Optimization
badsRoot = '/Users/samanthamontoya/Documents/MATLAB/toolboxes/bads';
pathCell = strsplit(path, pathsep);
badsSubpaths = pathCell(contains(pathCell, badsRoot));
if ~isempty(badsSubpaths)
    rmpath(strjoin(badsSubpaths, pathsep));
end
addpath(badsRoot);

% Parameter vector: [w_mel, w_lm_iprgc, w_s_iprgc, w_l_m_opponent]
w0  = [1.0, 0.2, -0.1, 0.0];
lb  = [-inf, -inf, -inf, 0];
ub  = [inf, inf, inf, inf];
plb = [0.0, -2.0, -2.0, 0];
pub = [2.0,  2.0,  2.0,  2.0];
fprintf('Fitting combined ipRGC + (L-M) weights to Stringham 2° data via BADS...\n');
bestW2 = bads(@(w) stringhamObjective(w, targetWl, targetLogSens, 2), ...
    w0, lb, ub, plb, pub);
fprintf('Optimal 2° Weights: Mel = %.2f, ipRGC L+M = %.2f, ipRGC S = %.2f, Opponent L-M = %.2f\n', ...
    bestW2(1), bestW2(2), bestW2(3), bestW2(4));

%% 4. Define Empirical Weights & Generate Base Signals
w_emp = [1.0, 0.2, -0.1, 0.0]; % [w_mel, w_lm, w_s, w_l_m]
plotWl = (380:1:700)';
[~, senseEmp] = calculateActionSpectrum(ones(size(plotWl)), plotWl, ...
    'fieldSize', 10, 'w_mel', w_emp(1), 'w_lm', w_emp(2), 'w_s', w_emp(3), 'w_l_m', w_emp(4));
[~, senseFit] = calculateActionSpectrum(ones(size(plotWl)), plotWl, ...
    'fieldSize', 2, 'w_mel', bestW2(1), 'w_lm', bestW2(2), 'w_s', bestW2(3), 'w_l_m', bestW2(4));

% Log normalized spectra for overall fit comparison
logEmpNorm = log10(max(senseEmp.combinedActionSpectrum(:), 1e-6));
logEmpNorm = logEmpNorm - max(logEmpNorm);
logFitNorm = log10(max(senseFit.combinedActionSpectrum(:), 1e-6));
logFitNorm = logFitNorm - max(logFitNorm);
targetNorm = targetLogSens - max(targetLogSens);

%% 5. Multi-Panel Visualizations (4x2 Layout)
figure('Color', 'w', 'Position', [100 20 1100 1300]);

% --- Subplot 1: Action Spectrum Comparison (Log Scale) ---
subplot(4, 2, 1);
hold on; grid off;
plot(targetWl, targetNorm, 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 6, ...
    'DisplayName', sprintf('Stringham 2003 (2%s Foveal)', char(176)));
plot(plotWl, logEmpNorm, '-', 'Color', [0.00, 0.50, 0.50], 'LineWidth', 2, ...
    'DisplayName', sprintf('Empirical Model (10%s)', char(176)));
plot(plotWl, logFitNorm, '--', 'Color', [0.00, 0.25, 0.50], 'LineWidth', 2.5, ...
    'DisplayName', sprintf('Best BADS Fit (2%s)', char(176)));
xlabel('Wavelength (nm)'); ylabel('Log_{10} Relative Sensitivity');
title('Action Spectrum Comparison');
xlim([380 650]); ylim([-1.2 0.1]); yticks(-1.2:0.2:0.2);
set(gca, 'TickDir', 'out', 'Box', 'off', 'FontSize', 10);
legend('Location', 'southwest', 'Box', 'off');

% --- Subplot 2: Individual Normalized Components ---
subplot(4, 2, 2);
hold on; grid off;
melNorm     = senseFit.Mel(:) ./ max(senseFit.Mel(:));
lNorm       = senseFit.L(:) ./ max(senseFit.L(:));
mNorm       = senseFit.M(:) ./ max(senseFit.M(:));
sNorm       = senseFit.S(:) ./ max(senseFit.S(:));
lmNorm      = senseFit.LM_combined(:) ./ max(senseFit.LM_combined(:));
lMinusMNorm = senseFit.LM_opponent(:) ./ max(senseFit.LM_opponent(:));
mMinusSNorm = senseFit.MS_opponent(:) ./ max(senseFit.MS_opponent(:));
plot(plotWl, melNorm, '-', 'Color', [0.00, 0.80, 0.80], 'LineWidth', 2, 'DisplayName', 'Melanopsin');
plot(plotWl, lNorm, '-', 'Color', [0.85, 0.10, 0.10], 'LineWidth', 2, 'DisplayName', 'L Cone Fundamental');
plot(plotWl, mNorm, '-', 'Color', [0.10, 0.70, 0.20], 'LineWidth', 2, 'DisplayName', 'M Cone Fundamental');
plot(plotWl, sNorm, '-', 'Color', [0.00, 0.45, 0.85], 'LineWidth', 2, 'DisplayName', 'S Cone Fundamental');
plot(plotWl, lmNorm, '-', 'Color', [0.90, 0.70, 0.00], 'LineWidth', 2, 'DisplayName', 'L+M Cone Fundamental');
plot(plotWl, lMinusMNorm, '-', 'Color', [0.60, 0.30, 0.10], 'LineWidth', 2, 'DisplayName', 'L-M Chromatic');
plot(plotWl, mMinusSNorm, '-', 'Color', [0.50, 0.20, 0.60], 'LineWidth', 2, 'DisplayName', 'M-S Chromatic');
yline(0, 'k:', 'HandleVisibility', 'off');
xlabel('Wavelength (nm)'); ylabel('Normalized Sensitivity (Max = 1)');
title('Normalized Pathway Components (2°)');
xlim([380 650]); ylim([-0.5 1.1]);
set(gca, 'TickDir', 'out', 'Box', 'off', 'FontSize', 10);
legend('Location', 'northeast', 'Box', 'off');

% --- Subplot 3: Moderate L-M Weight Sweep on Empirical Base ---
subplot(4, 2, 3);
hold on; grid off;
plot(targetWl, targetNorm, 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 6, ...
    'HandleVisibility', 'off');
w_lm_vals = [0.0, 0.1, 0.25, 0.5, 0.75, 1.0];
sweepColorsLM = copper(length(w_lm_vals));
for i = 1:length(w_lm_vals)
    w_lm_curr = w_lm_vals(i);
    [~, senseSweep] = calculateActionSpectrum(ones(size(plotWl)), plotWl, ...
        'fieldSize', 2, 'w_mel', w_emp(1), 'w_lm', w_emp(2), 'w_s', w_emp(3), 'w_l_m', w_lm_curr);
    logSweep = log10(max(senseSweep.combinedActionSpectrum(:), 1e-6));
    logSweep = logSweep - max(logSweep);
    plot(plotWl, logSweep, 'LineWidth', 1.8, 'Color', sweepColorsLM(i,:), ...
        'DisplayName', sprintf('w_{L-M} = %.2f', w_lm_curr));
end
xlabel('Wavelength (nm)'); ylabel('Log_{10} Relative Sensitivity');
title('Effect of Moderate L-M Addition on Shape (2°)');
xlim([380 650]); ylim([-1.2 0.1]); yticks(-1.2:0.2:0.2);
set(gca, 'TickDir', 'out', 'Box', 'off', 'FontSize', 10);
legend('Location', 'southeast', 'Box', 'off');

% --- Subplot 4: Moderate M-S Weight Sweep on Empirical Base ---
subplot(4, 2, 4);
hold on; grid off;
plot(targetWl, targetNorm, 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 6, ...
    'HandleVisibility', 'off');
w_ms_vals = [0.0, 0.1, 0.25, 0.5, 0.75, 1.0];
sweepColorsMS = winter(length(w_ms_vals));
for i = 1:length(w_ms_vals)
    w_ms_curr = w_ms_vals(i);
    [~, senseSweep] = calculateActionSpectrum(ones(size(plotWl)), plotWl, ...
        'fieldSize', 2, 'w_mel', w_emp(1), 'w_lm', w_emp(2), 'w_s', w_emp(3), 'w_m_s', w_ms_curr);
    logSweep = log10(max(senseSweep.combinedActionSpectrum(:), 1e-6));
    logSweep = logSweep - max(logSweep);
    plot(plotWl, logSweep, 'LineWidth', 1.8, 'Color', sweepColorsMS(i,:), ...
        'DisplayName', sprintf('w_{M-S} = %.2f', w_ms_curr));
end
xlabel('Wavelength (nm)'); ylabel('Log_{10} Relative Sensitivity');
title('Effect of Moderate M-S Addition on Shape (2°)');
xlim([380 650]); ylim([-1.2 0.1]); yticks(-1.2:0.2:0.2);
set(gca, 'TickDir', 'out', 'Box', 'off', 'FontSize', 10);
legend('Location', 'southeast', 'Box', 'off');

% --- Subplot 5: ipRGC Cone Weight Sweep (L+M vs -S) ---
subplot(4, 2, 5);
hold on; grid off;
plot(targetWl, targetNorm, 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 6, ...
    'HandleVisibility', 'off');
w_s_sweep = [0.0, -0.05, -0.10, -0.20, -0.40];
iprgcColors = summer(length(w_s_sweep));
for i = 1:length(w_s_sweep)
    ws_curr = w_s_sweep(i);
    [~, senseSweep] = calculateActionSpectrum(ones(size(plotWl)), plotWl, ...
        'fieldSize', 2, 'w_mel', 1.0, 'w_lm', 0.2, 'w_s', ws_curr, 'w_l_m', 0.0, 'w_m_s', 0.0);
    logSweep = log10(max(senseSweep.combinedActionSpectrum(:), 1e-6));
    logSweep = logSweep - max(logSweep);
    plot(plotWl, logSweep, 'LineWidth', 1.8, 'Color', iprgcColors(i,:), ...
        'DisplayName', sprintf('w_{L+M}=0.2, w_S=%.2f', ws_curr));
end
xlabel('Wavelength (nm)'); ylabel('Log_{10} Relative Sensitivity');
title('ipRGC Pathway: (L+M) - S Cone Weight Sweep (2°)');
xlim([380 650]); ylim([-1.2 0.1]); yticks(-1.2:0.2:0.2);
set(gca, 'TickDir', 'out', 'Box', 'off', 'FontSize', 10);
legend('Location', 'southeast', 'Box', 'off');

% --- Subplot 6: Cone-Specific Macular Pigment Density Sweep via CIE Fundamentals ---
subplot(4, 2, 6);
hold on; grid off;
plot(targetWl, targetNorm, 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 6, ...
    'HandleVisibility', 'off');
dmac_vals = [-100, -50, 0, 50, 100];
mpodColors = parula(length(dmac_vals));
for i = 1:length(dmac_vals)
    dmac_curr = dmac_vals(i);
    [~, senseMPSweep] = calculateActionSpectrum(ones(size(plotWl)), plotWl, ...
        'fieldSize', 2, 'w_mel', w_emp(1), 'w_lm', w_emp(2), 'w_s', w_emp(3), ...
        'dmac_cone', dmac_curr);
    logMPSweep = log10(max(senseMPSweep.combinedActionSpectrum(:), 1e-6));
    logMPSweep = logMPSweep - max(logMPSweep);
    plot(plotWl, logMPSweep, 'LineWidth', 1.8, 'Color', mpodColors(i,:), ...
        'DisplayName', sprintf('\\Delta Macular Density = %+d%%', dmac_curr));
end
xlabel('Wavelength (nm)'); ylabel('Log_{10} Relative Sensitivity');
title('Cone-Only Macular Density Sweep via CIE Fundamentals');
xlim([380 650]); ylim([-1.2 0.1]); yticks(-1.2:0.2:0.2);
set(gca, 'TickDir', 'out', 'Box', 'off', 'FontSize', 10);
legend('Location', 'southeast', 'Box', 'off');

% --- Subplot 7: Total Lens Density Sweep (Cones + Melanopsin) ---
subplot(4, 2, 7);
hold on; grid off;
plot(targetWl, targetNorm, 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 6, ...
    'HandleVisibility', 'off');
dlens_vals = [-100, -50, 0, 50, 100];
lensColors = autumn(length(dlens_vals));
for i = 1:length(dlens_vals)
    dlens_curr = dlens_vals(i);
    [~, senseLensSweep] = calculateActionSpectrum(ones(size(plotWl)), plotWl, ...
        'fieldSize', 2, 'w_mel', w_emp(1), 'w_lm', w_emp(2), 'w_s', w_emp(3), ...
        'dlens', dlens_curr);
    logLensSweep = log10(max(senseLensSweep.combinedActionSpectrum(:), 1e-6));
    logLensSweep = logLensSweep - max(logLensSweep);
    plot(plotWl, logLensSweep, 'LineWidth', 1.8, 'Color', lensColors(i,:), ...
        'DisplayName', sprintf('\\Delta Lens Density = %+d%%', dlens_curr));
end
xlabel('Wavelength (nm)'); ylabel('Log_{10} Relative Sensitivity');
title('Total Lens Density Sweep (Cones + Melanopsin)');
xlim([380 650]); ylim([-1.2 0.1]); yticks(-1.2:0.2:0.2);
set(gca, 'TickDir', 'out', 'Box', 'off', 'FontSize', 10);
legend('Location', 'southeast', 'Box', 'off');

% --- Subplot 8: Placeholder / Empty Grid Tile ---
subplot(4, 2, 8);
axis off;

%% --- Support Functions ---
function rmse = stringhamObjective(w, targetWl, targetLogSens, fieldSize)
[~, sense] = calculateActionSpectrum(ones(size(targetWl)), targetWl, ...
    'fieldSize', fieldSize, 'w_mel', w(1), 'w_lm', w(2), 'w_s', w(3), 'w_l_m', w(4));
modelVals = sense.combinedActionSpectrum(:);
targetVals = targetLogSens(:);
modelLog = log10(max(modelVals, 1e-6));
offset = mean(targetVals - modelLog);
modelLog = modelLog + offset;
rmse = sqrt(mean((targetVals - modelLog).^2));
end

function [squintSignal, sense] = calculateActionSpectrum(watts, lambda, options)
arguments
    watts (1,:) double
    lambda (1,:) double
    options.age (1,1) double = 25
    options.fieldSize (1,1) double = 10
    options.pupilSize (1,1) double = 3
    options.w_mel (1,1) double = 1.0
    options.w_lm (1,1) double = 0.2
    options.w_s (1,1) double = -0.1
    options.w_l_m (1,1) double = 0.0
    options.w_m_s (1,1) double = 0.0
    options.dmac_cone (1,1) double = 0 % Macular density adjustment (%) for cones only
    options.dlens (1,1) double = 0     % Lens density adjustment (%) for ALL cell types
end

lambdaRow = lambda(:)';
S = [lambdaRow(1) (lambdaRow(2)-lambdaRow(1)) length(lambdaRow)];

%% 1. Retinal Sensitivity (Cones)
if options.dmac_cone ~= 0 || options.dlens ~= 0
    indDiffParamsCone = struct(...
        'dlens', options.dlens, ...
        'dmac', options.dmac_cone, ...
        'dcone', [0; 0; 0], ...
        'dphotopigment', [0; 0; 0], ...
        'lambdaMaxShift', [0; 0; 0], ...
        'shiftType', 'linear' ...  
    );
    
    [T_lms_quantal_norm] = ComputeCIEConeFundamentals( ...
        S, options.fieldSize, options.age, options.pupilSize, ...
        [], [], [], [], [], [], indDiffParamsCone);
else
    [T_lms_quantal_norm] = ComputeCIEConeFundamentals( ...
        S, options.fieldSize, options.age, options.pupilSize);
end

%% 2. Melanopsin Fundamental with Lens Adjustment
[T_mel_quantal_norm] = ComputeCIEMelFundamental( ...
    S, options.fieldSize, max(20, options.age), options.pupilSize, []);

T_mel_energy = EnergyToQuanta(S, T_mel_quantal_norm')';
T_lms_energy = EnergyToQuanta(S, T_lms_quantal_norm')';

if options.dlens ~= 0
    [~, dLensMag] = LensTransmittance(S, 'Human', 'CIE', max(20, options.age));
    lensScaleFactor = 10 .^ (-dLensMag(:)' .* (options.dlens / 100));
    T_mel_energy = T_mel_energy .* lensScaleFactor;
end

sense.Mel = T_mel_energy(1,:) ./ max(T_mel_energy(1,:));
sense.L   = T_lms_energy(1,:) ./ max(T_lms_energy(1,:));
sense.M   = T_lms_energy(2,:) ./ max(T_lms_energy(2,:));
sense.S   = T_lms_energy(3,:) ./ max(T_lms_energy(3,:));
tempLM_ret = T_lms_energy(1,:) + T_lms_energy(2,:);
sense.LM_combined = tempLM_ret ./ max(tempLM_ret);

%% 3. INDEPENDENT PATHWAY CALCULATIONS
sense.iprgcActionSpectrum = (options.w_mel * sense.Mel) + ...
    (options.w_lm  * sense.LM_combined) + ...
    (options.w_s   * sense.S);

sense.LM_opponent = sense.L - sense.M;
sense.MS_opponent = sense.M - sense.S;

sense.combinedActionSpectrum = sense.iprgcActionSpectrum + ...
    (options.w_l_m * sense.LM_opponent) + ...
    (options.w_m_s * sense.MS_opponent);

%% 4. TOTAL SIGNAL CALCULATION
totalNeuralDrive = sum(sense.combinedActionSpectrum .* watts);
squintSignal = log10(max(totalNeuralDrive, 1e-4));
end