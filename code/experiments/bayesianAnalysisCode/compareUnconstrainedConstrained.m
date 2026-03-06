% This code is to compare the log likelihoods of our constrained vs
% unconstrained fits for cases where sigmaTest < sigmaRef. 

%set up paths
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir = 'FLIC_analysis';
projectName = 'dichopticFlicker';
experimentName = 'sigmaData';

% UNCONSTRAINED
% Pull the sigma data from the unconstrained fits
dataDir = fullfile(dropBoxBaseDir, dropBoxSubDir, projectName, experimentName);
migraineUnconstrainedFilePath = fullfile(dataDir, '15Migrainer_individualSigmaFits.mat');
controlUnconstrainedFilePath  = fullfile(dataDir, '15Control_individualSigmaFits.mat');
%load
% data is subj x contrasts x lightLevels x freqs
migraineUnconFits = load(migraineUnconstrainedFilePath);
controlUnconFits  = load(controlUnconstrainedFilePath);

% Identify cases where sigmaTest < sigmaRef
migraineUnconIdx = migraineUnconFits.sigmaTestMatrix < migraineUnconFits.sigmaRefMatrix;
controlUnconIdx  = controlUnconFits.sigmaTestMatrix < controlUnconFits.sigmaRefMatrix;

% Identify cases where in addition to being < sigmaRef, sigmaTest < 0.1
migraineUnconTinyIdx = migraineUnconFits.sigmaTestMatrix(migraineUnconIdx) < 0.1;
controlUnconTinyIdx  = controlUnconFits.sigmaTestMatrix(controlUnconIdx) < 0.1;

% Pull the corresponding fVals (nll) from the fValMatrix
migraineUnconfVals = migraineUnconFits.fValMatrix(migraineUnconIdx); 
controlUnconfVals = controlUnconFits.fValMatrix(controlUnconIdx); 
% Then subset the tiny ones
migraineUnconTinyfVals = migraineUnconfVals(migraineUnconTinyIdx); 
controlUnconTinyfVals = controlUnconfVals(controlUnconTinyIdx);

% CONSTRAINED
% Pull the corresponding sigma values from the constrained fits
dataDir = fullfile(dropBoxBaseDir, dropBoxSubDir, projectName, experimentName);
migraineConstrainedFilePath = fullfile(dataDir, '15Migrainer_individualSigmaFitsConstrained.mat');
controlConstrainedFilePath  = fullfile(dataDir, '15Control_individualSigmaFitsConstrained.mat');
%load
% data is subj x contrasts x lightLevels x freqs
migraineConFits = load(migraineConstrainedFilePath);
controlConFits  = load(controlConstrainedFilePath);

% Pull the corresponding fVals (nll) from the fValMatrix
migraineConfVals = migraineConFits.fValMatrix(migraineUnconIdx); 
controlConfVals = controlConFits.fValMatrix(controlUnconIdx); 
% Then subset the tiny ones
migraineConTinyfVals = migraineConfVals(migraineUnconTinyIdx); 
controlConTinyfVals = controlConfVals(controlUnconTinyIdx);

% Scatter plot: unconstrained vs constrained log-likelihoods
figure('Color', 'w', 'Name', 'Log-Likelihood: Unconstrained vs Constrained');
hold on;

% Colors
colMigraine = [0.8 0.3 0.3]; 
colControl = [0.3 0.3 0.8];

% Migraine
% Plot all points
scatter(migraineUnconfVals, migraineConfVals, 60, colMigraine, 'filled', 'MarkerFaceAlpha', 0.5);
% Highlight tiny ones
scatter(migraineUnconTinyfVals, migraineConTinyfVals, 60, colMigraine, 'filled', 'LineWidth', 1.5, ...
    'MarkerFaceAlpha', 1);

% Control
scatter(controlUnconfVals, controlConfVals, 60, colControl, 'filled', 'MarkerFaceAlpha', 0.5);
scatter(controlUnconTinyfVals, controlConTinyfVals, 60, colControl, 'filled', 'LineWidth', 1.5, ...
    'MarkerFaceAlpha', 1);

% Identity line for reference
xl = xlim; yl = ylim;
lims = [min([xl yl]) max([xl yl])];
plot(lims, lims, 'k--', 'LineWidth', 1.2);

% Labels and styling
xlabel('Unconstrained negative log-likelihood (fVal)');
ylabel('Constrained negative log-likelihood (fVal)');
title('Comparison of unconstrained vs constrained fVals for sigmaTest < sigmaRef');
legend({'Migraine', 'Migraine < 0.1', 'Control', 'Control < 0.1'}, 'Location', 'best');
axis square; grid on;