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

%% 4. Define Empirical Weights & Generate Signals
w_emp = [1.0, 0.2, -0.1, 0.0]; % [w_mel, w_lm, w_s, w_l_m]
plotWl = (380:1:700)';

[~, senseEmp] = calculateActionSpectrum(ones(size(plotWl)), plotWl, ...
    'fieldSize', 10, 'w_mel', w_emp(1), 'w_lm', w_emp(2), 'w_s', w_emp(3), 'w_l_m', w_emp(4));
[~, senseFit] = calculateActionSpectrum(ones(size(plotWl)), plotWl, ...
    'fieldSize', 2, 'w_mel', bestW2(1), 'w_lm', bestW2(2), 'w_s', bestW2(3), 'w_l_m', bestW2(4));

% Log normalized spectra
logEmpNorm = log10(max(senseEmp.combinedActionSpectrum(:), 1e-6));
logEmpNorm = logEmpNorm - max(logEmpNorm);
logFitNorm = log10(max(senseFit.combinedActionSpectrum(:), 1e-6));
logFitNorm = logFitNorm - max(logFitNorm);
targetNorm = targetLogSens - max(targetLogSens);

%% 5. Multi-Panel Visualizations
figure('Color', 'w', 'Position', [100 100 1100 800]);

% --- Subplot 1: Action Spectrum Comparison (Log Scale) ---
subplot(2, 2, 1);
hold on; grid off;
plot(targetWl, targetNorm, 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 6, ...
    'DisplayName', sprintf('Stringham 2003 (2%s Foveal)', char(176)));
plot(plotWl, logEmpNorm, '-', 'Color', [0.00, 0.50, 0.50], 'LineWidth', 2, ...
    'DisplayName', sprintf('Empirical Model (10%s)', char(176)));
plot(plotWl, logFitNorm, '--', 'Color', [0.00, 0.25, 0.50], 'LineWidth', 2.5, ...
    'DisplayName', sprintf('Best Combined Fit (2%s)', char(176)));
xlabel('Wavelength (nm)'); ylabel('Log_{10} Relative Sensitivity');
title('Action Spectrum Comparison');
xlim([380 650]); ylim([-1.2 0.1]); yticks(-1.2:0.2:0.2);
set(gca, 'TickDir', 'out', 'Box', 'off', 'FontSize', 11);
legend('Location', 'southwest', 'Box', 'off');

% --- Subplot 2: Individual Normalized Components ---
subplot(2, 2, 2);
hold on; grid off;

% 1. Extract raw spectra for 2° fit
melCurve = senseFit.Mel(:);
lCurve   = senseFit.L(:);
mCurve   = senseFit.M(:);
sCurve   = senseFit.S(:);
lmCurve  = senseFit.LM_combined(:);
lMinusMCurve = senseFit.LM_opponent(:);

% 2. Normalize each component curve individually to a max of 1.0
melNorm     = melCurve ./ max(melCurve);
lNorm       = lCurve ./ max(lCurve);
mNorm       = mCurve ./ max(mCurve);
sNorm       = sCurve ./ max(sCurve);
lmNorm      = lmCurve ./ max(lmCurve);
lMinusMNorm = lMinusMCurve ./ max(lMinusMCurve);

% 3. Plot curves with requested colors
% Cyan [0 0.8 0.8]
plot(plotWl, melNorm, '-', 'Color', [0.00, 0.80, 0.80], 'LineWidth', 2, ...
    'DisplayName', 'Melanopsin');

% Red [0.85 0.1 0.1]
plot(plotWl, lNorm, '-', 'Color', [0.85, 0.10, 0.10], 'LineWidth', 2, ...
    'DisplayName', 'L Cone Fundamental');

% Green [0.1 0.7 0.2]
plot(plotWl, mNorm, '-', 'Color', [0.10, 0.70, 0.20], 'LineWidth', 2, ...
    'DisplayName', 'M Cone Fundamental');

% Blue [0 0.45 0.85]
plot(plotWl, sNorm, '-', 'Color', [0.00, 0.45, 0.85], 'LineWidth', 2, ...
    'DisplayName', 'S Cone Fundamental');

% Yellow / Gold [0.9 0.7 0.0]
plot(plotWl, lmNorm, '-', 'Color', [0.90, 0.70, 0.00], 'LineWidth', 2, ...
    'DisplayName', 'L+M Cone Fundamental');

% Brown [0.6 0.3 0.1]
plot(plotWl, lMinusMNorm, '-', 'Color', [0.60, 0.30, 0.10], 'LineWidth', 2, ...
    'DisplayName', 'L-M Chromatic');

% 4. Formatting
yline(0, 'k:', 'HandleVisibility', 'off'); % Reference line for zero-crossing
xlabel('Wavelength (nm)'); 
ylabel('Normalized Sensitivity (Max = 1)');
title('Normalized Pathway Components (2°)');
xlim([380 650]); ylim([-0.5 1.1]);
set(gca, 'TickDir', 'out', 'Box', 'off', 'FontSize', 11);
legend('Location', 'northeast', 'Box', 'off');

% --- Subplot 3: Macular Pigment Sweep ---
subplot(2, 2, 3);
hold on; grid off;
if exist('ComputeMacularPigment', 'file') == 2
    [~, mpAbsorbance] = ComputeMacularPigment(plotWl);
elseif exist('macular', 'file') == 2
    [~, mpAbsorbance] = macular(plotWl);
else
    mpAbsorbance = exp(-((plotWl - 460) / 40).^2);
end

mpScales = [0.0, 0.5, 1.0, 1.5, 2.0];
mpColors = parula(length(mpScales) + 1);
plot(targetWl, targetNorm, 'ko', 'MarkerFaceColor', 'k', 'MarkerSize', 6, ...
    'DisplayName', 'Stringham Data');

baseAS = max(senseFit.combinedActionSpectrum(:), 1e-6);
for i = 1:length(mpScales)
    scale = mpScales(i);
    mpTransmittance = 10 .^ (-scale * mpAbsorbance(:));
    filteredAS = baseAS .* mpTransmittance;
    logFiltered = log10(filteredAS);
    logFiltered = logFiltered - max(logFiltered);
    plot(plotWl, logFiltered, 'LineWidth', 1.8, 'Color', mpColors(i,:), ...
        'DisplayName', sprintf('Fit + %0.1fx MP', scale));
end
xlabel('Wavelength (nm)'); ylabel('Log_{10} Relative Sensitivity');
title('Macular Pigment Sweep on Best Fit Model');
xlim([380 650]); ylim([-1.2 0.1]); yticks(-1.2:0.2:0.2);
set(gca, 'TickDir', 'out', 'Box', 'off', 'FontSize', 11);
legend('Location', 'southeast', 'Box', 'off');

% --- Subplot 4: Optimized Weights Bar Plot ---
subplot(2, 2, 4);
hold on; grid off;
paramNames = {'w_{Mel}', 'w_{L+M}', 'w_S', 'w_{L-M}'};
b = bar(1:4, bestW2, 0.5, 'FaceColor', 'flat');
b.CData(1,:) = [0.00, 0.20, 0.60];
b.CData(2,:) = [0.20, 0.50, 0.70];
b.CData(3,:) = [0.40, 0.70, 0.90];
b.CData(4,:) = [0.85, 0.45, 0.10]; % L-M parameter highlighted in orange

yline(0, 'k--');
set(gca, 'XTick', 1:4, 'XTickLabel', paramNames, 'TickDir', 'out', 'Box', 'off', 'FontSize', 11);
ylabel('Weight Value'); title('Optimized Weight Coefficients (2°)');

for i = 1:length(bestW2)
    text(i, bestW2(i) + sign(bestW2(i))*0.03, sprintf('%.2f', bestW2(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold');
end

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
    end
    
    lambdaCol = lambda(:); 
    lambdaRow = lambda(:)'; 
    S = [lambdaRow(1) (lambdaRow(2)-lambdaRow(1)) length(lambdaRow)];
    
    %% 1. INTRINSIC SENSITIVITY (Nomograms)
    sense.Intrinsic.Mel = PhotopigmentNomogram(lambdaCol, 480, 'Govardovskii')';
    absL = PhotopigmentNomogram(lambdaCol, 558.9, 'StockmanSharpe')';
    absM = PhotopigmentNomogram(lambdaCol, 530.3, 'StockmanSharpe')';
    absS = PhotopigmentNomogram(lambdaCol, 420.7, 'StockmanSharpe')';
    sense.Intrinsic.LM = (absL + absM) ./ max(absL + absM);
    sense.Intrinsic.S  = absS ./ max(absS);
    
    %% 2. RETINAL SENSITIVITY (Lens filtered)
    [T_mel_quantal_norm] = ComputeCIEMelFundamental(S, options.fieldSize, options.age, options.pupilSize, []);
    [T_lms_quantal_norm] = ComputeCIEConeFundamentals(S, options.fieldSize, options.age, options.pupilSize);
    T_mel_energy = EnergyToQuanta(S, T_mel_quantal_norm')';
    T_lms_energy = EnergyToQuanta(S, T_lms_quantal_norm')';
    
    sense.Mel = T_mel_energy(1,:) ./ max(T_mel_energy(1,:));
    sense.L   = T_lms_energy(1,:) ./ max(T_lms_energy(1,:));
    sense.M   = T_lms_energy(2,:) ./ max(T_lms_energy(2,:));
    sense.S   = T_lms_energy(3,:) ./ max(T_lms_energy(3,:));
    
    tempLM_ret = T_lms_energy(1,:) + T_lms_energy(2,:);
    sense.LM_combined = tempLM_ret ./ max(tempLM_ret);
    
    %% 3. INDEPENDENT PATHWAY CALCULATIONS
    % A. Pure ipRGC Pathway
    sense.iprgcActionSpectrum = (options.w_mel * sense.Mel) + ... 
                                (options.w_lm  * sense.LM_combined) + ...
                                (options.w_s   * sense.S);
            
    % B. Separate Opponent L-M Pathway (+L, -M)
    sense.LM_opponent = sense.L - sense.M;
    
    % C. Downstream Combination
    sense.combinedActionSpectrum = sense.iprgcActionSpectrum + ...
                                   (options.w_l_m * sense.LM_opponent);

    %% 4. TOTAL SIGNAL CALCULATION
    totalNeuralDrive = sum(sense.combinedActionSpectrum .* watts);
    squintSignal = log10(max(totalNeuralDrive, 1e-4));
end