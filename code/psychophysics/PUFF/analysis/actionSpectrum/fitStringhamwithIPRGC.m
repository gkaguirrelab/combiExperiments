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

% Purge any polluted subfolders (like /private or .git) from MATLAB path
pathCell = strsplit(path, pathsep);
badsSubpaths = pathCell(contains(pathCell, badsRoot));
if ~isempty(badsSubpaths)
    rmpath(strjoin(badsSubpaths, pathsep));
end

% Re-add strictly the top-level BADS root directory
addpath(badsRoot);

w0  = [1.0, 0.2, -0.1];  
lb  = [-inf, -inf, -inf];      
ub  = [inf, inf, inf];        

fprintf('Fitting ipRGC weights to Stringham 2° data via BADS...\n');

% Run BADS directly
bestW2 = bads(@(w) stringhamObjective(w, targetWl, targetLogSens, 2), ...
    w0, lb, ub, plb, pub);

fprintf('Optimal 2° Weights: Mel = %.2f, LM = %.2f, S = %.2f\n', ...
    bestW2(1), bestW2(2), bestW2(3));

%% 4. Define Empirical Weights & Generate Plots
w_emp = [1.0, 0.2, -0.1]; % [w_mel, w_lm, w_s]
plotWl = (380:1:700)';

[~, senseEmp] = calculateActionSpectrum(ones(size(plotWl)), plotWl, ...
    'fieldSize', 10, 'w_mel', w_emp(1), 'w_lm', w_emp(2), 'w_s', w_emp(3));

[~, senseFit] = calculateActionSpectrum(ones(size(plotWl)), plotWl, ...
    'fieldSize', 2, 'w_mel', bestW2(1), 'w_lm', bestW2(2), 'w_s', bestW2(3));

logEmpNorm = log10(max(senseEmp.iprgcActionSpectrum(:), 1e-6));
logEmpNorm = logEmpNorm - max(logEmpNorm);

logFitNorm = log10(max(senseFit.iprgcActionSpectrum(:), 1e-6));
logFitNorm = logFitNorm - max(logFitNorm);

targetNorm = targetLogSens - max(targetLogSens);

figure('Color', 'w', 'Position', [100 100 800 450]); % Made slightly wider for right-hand legend
hold on; grid off;

% 1. Stringham Data (Markers)
plot(targetWl, targetNorm, 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 7, ...
    'DisplayName', sprintf('Stringham 2003 (2%s Foveal)', char(176)));

% 2. Empirical Model (Deep Cyan / Teal)
plot(plotWl, logEmpNorm, '-', 'Color', [0.00, 0.50, 0.50], 'LineWidth', 2.5, ...
    'DisplayName', sprintf('Empirical ipRGC (10%s)\n[w=[%.1f, %.1f, %.1f]]', char(176), w_emp));

% 3. Best Fit Model (Dashed Line)
plot(plotWl, logFitNorm, '--', 'Color', [0.0, 0.45, 0.74], 'LineWidth', 2.5, ...
    'DisplayName', sprintf('Best ipRGC Fit (2%s)\n[w=[%.2f, %.2f, %.2f]]', char(176), bestW2));

xlabel('Wavelength (nm)');
ylabel('Log_{10} Relative Sensitivity');
title('Action Spectrum Comparison');
yticks([-1.2:0.2:0.2])
xlim([380 650]); ylim([-1.2 0.1]);

set(gca, 'TickDir', 'out', 'Box', 'off', 'FontSize', 12);

% --- Right-side Legend (No Box) ---
legend('Location', 'eastoutside', 'Box', 'off', 'NumColumns', 1);
% --- Plot 2: Macular Pigment Filtering Sweep ---
% Compute Macular Pigment absorbance profile
if exist('ComputeMacularPigment', 'file') == 2
    [~, mpAbsorbance] = ComputeMacularPigment(plotWl);
elseif exist('macular', 'file') == 2
    [~, mpAbsorbance] = macular(plotWl);
else
    % Fallback: Gaussian approximation of macular pigment optical density (peaks ~460 nm)
    mpAbsorbance = exp(-((plotWl - 460) / 40).^2);
end

mpScales = [0.0, 0.5, 1.0, 1.5, 2.0];
mpColors = parula(length(mpScales) + 1);

figure('Color', 'w', 'Position', [820 100 700 550]);
hold on; grid off;

plot(targetWl, targetNorm, 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 7, ...
    'DisplayName', sprintf('Stringham Data (2%s)', char(176)));

baseAS = max(senseEmp.iprgcActionSpectrum(:), 1e-6);

for i = 1:length(mpScales)
    scale = mpScales(i);
    mpTransmittance = 10 .^ (-scale * mpAbsorbance(:));
    filteredAS = baseAS .* mpTransmittance;
    
    logFiltered = log10(filteredAS);
    logFiltered = logFiltered - max(logFiltered);
    
    plot(plotWl, logFiltered, 'LineWidth', 2, 'Color', mpColors(i,:), ...
        'DisplayName', sprintf('Empirical + %0.1fx MP Density', scale));
end

xlabel('Wavelength (nm)');
ylabel('Log_{10} Relative Sensitivity');
title(sprintf('Macular Pigment Density Sweep on Our 10%s Action Spectrum', char(176)));
xlim([380 650]); ylim([-1.2 0.1]);
yticks([-1.2:0.2:0.2])

set(gca, 'TickDir', 'out', 'Box', 'off', 'FontSize', 12);
legend('Location', 'southoutside', 'NumColumns', 2);

%% --- Support Objective Function ---
function rmse = stringhamObjective(w, targetWl, targetLogSens, fieldSize)
    [~, sense] = calculateActionSpectrum(ones(size(targetWl)), targetWl, ...
        'fieldSize', fieldSize, 'w_mel', w(1), 'w_lm', w(2), 'w_s', w(3));
    
    modelVals = sense.iprgcActionSpectrum(:);
    targetVals = targetLogSens(:);
    
    modelLog = log10(max(modelVals, 1e-6));
    offset = mean(targetVals - modelLog);
    modelLog = modelLog + offset;
    
    rmse = sqrt(mean((targetVals - modelLog).^2));
end