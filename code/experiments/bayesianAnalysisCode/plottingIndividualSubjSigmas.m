% Code to plot sigma values for individual subjects
% Split into low and high contrast sigma values
% Collapsed across light level and reference frequency

% Variable to decide between plotting light levels vs contrasts
contrast = true;

% Load sigma matrices
sigmaMatrixControls = load('/Users/melanopsin/Documents/MATLAB/projects/combiExperiments/code/psychophysics/DCPT/sameDiffModel/sigma data for different models/12ControlBayesianTwoSigmaData.mat', ...
    'sigmaMatrix1').sigmaMatrix1;
sigmaMatrixMigrainers = load('/Users/melanopsin/Documents/MATLAB/projects/combiExperiments/code/psychophysics/DCPT/sameDiffModel/sigma data for different models/11MigraineBayesianTwoSigmaData.mat', ...
    'sigmaMatrix1').sigmaMatrix1;

% Load sigma zero matrices
sigmaZeroMatrixControls = load('/Users/melanopsin/Documents/MATLAB/projects/combiExperiments/code/psychophysics/DCPT/sameDiffModel/sigma data for different models/12ControlBayesianTwoSigmaData.mat', ...
    'sigmaMatrix2').sigmaMatrix2;
sigmaZeroMatrixMigrainers = load('/Users/melanopsin/Documents/MATLAB/projects/combiExperiments/code/psychophysics/DCPT/sameDiffModel/sigma data for different models/11MigraineBayesianTwoSigmaData.mat', ...
    'sigmaMatrix2').sigmaMatrix2;

% Combine the control and migrainer sigma matrices
sigmaMatrix = cat(1, sigmaMatrixControls, sigmaMatrixMigrainers);
sigmaZeroMatrix = cat(1, sigmaZeroMatrixControls, sigmaZeroMatrixMigrainers);

if contrast
    % Average across light level (dim 3) and reference frequency (dim 4)
    % Result: [Subj × Contrast]
    sigmaSubj = squeeze(mean(mean(sigmaMatrix, 3), 4));
    sigmaZeroSubj = squeeze(mean(mean(sigmaZeroMatrix, 3), 4));
else
    % Average across contrast (dim 2) and reference frequency (dim 4)
    % Result: [Subj × Light Level]
    sigmaSubj = squeeze(mean(mean(sigmaMatrix, 2), 4));
    sigmaZeroSubj = squeeze(mean(mean(sigmaZeroMatrix, 2), 4));
end

lowC  = 1;  % index for low contrast (or light level)
highC = 2;  % index for high contrast

% Sigma
sigmaLow  = sigmaSubj(:, lowC);
sigmaHigh = sigmaSubj(:, highC);

% Sigma zero
sigmaZeroLow  = sigmaZeroSubj(:, lowC);
sigmaZeroHigh = sigmaZeroSubj(:, highC);

% Plotting
figure;
hold on;

% Sigma (blue)
scatter(sigmaLow, sigmaHigh, 60, 'b', 'filled');

% Sigma zero (red)
scatter(sigmaZeroLow, sigmaZeroHigh, 60, 'r', 'filled');

% Axes formatting
xlim([0 2.5]);
ylim([0 2.5]);

% Unity line
plot(xlim, xlim, 'k-', 'LineWidth', 1.5);
if contrast
    xlabel('Low contrast value');
    ylabel('High contrast value');
    title('Low vs High Contrast: \sigma and \sigma_0');
else
    xlabel('Low light level value');
    ylabel('High light level value');
    title('Low vs High Light Level: \sigma and \sigma_0');
end

legend({'Sigma', 'Sigma Zero'}, 'Location', 'northwest');

hold off;
