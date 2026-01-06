% Code to compare the sigma values from the model with the SDT
% framework and the model with the Bayesian framework (one sigma version)

% Load SDT sigma data for controls
SDTSigmaControl = load('/Users/rubybouh/Documents/MATLAB/projects/combiExperiments/code/psychophysics/DCPT/sameDiffModel/sigma data for different models/12ControlSDTSigmaData.mat', ...
    'sigmaMatrix');
% Load SDT sigma data for migrainers
SDTSigmaMigraine = load('/Users/rubybouh/Documents/MATLAB/projects/combiExperiments/code/psychophysics/DCPT/sameDiffModel/sigma data for different models/11MigraineSDTSigmaData.mat', ...
    'sigmaMatrix');

% Load Bayesian sigma data for controls
% bayesianSigmaControl = load('/Users/rubybouh/Documents/MATLAB/projects/combiExperiments/code/psychophysics/DCPT/sameDiffModel/sigma data for different models/12ControlBayesianSigmaData.mat', ...
%    'sigmaMatrix');
% Load Bayesian sigma data for migrainers
%bayesianSigmaMigraine = load('/Users/rubybouh/Documents/MATLAB/projects/combiExperiments/code/psychophysics/DCPT/sameDiffModel/sigma data for different models/11MigraineBayesianSigmaData', ...
%    'sigmaMatrix');

% Load Bayesian TWO sigma data for controls
bayesianSigmaControl = load('/Users/rubybouh/Documents/MATLAB/projects/combiExperiments/code/psychophysics/DCPT/sameDiffModel/sigma data for different models/12ControlBayesianTwoSigmaData.mat', ...
    'sigmaMatrix1');
% Load Bayesian TWO sigma data for migrainers
bayesianSigmaMigraine = load('/Users/rubybouh/Documents/MATLAB/projects/combiExperiments/code/psychophysics/DCPT/sameDiffModel/sigma data for different models/11MigraineBayesianTwoSigmaData.mat', ...
    'sigmaMatrix1');

% Collapsing matrices into vectors
SDTSigmaControl = SDTSigmaControl.sigmaMatrix(:);
SDTSigmaMigraine = SDTSigmaMigraine.sigmaMatrix(:);
bayesianSigmaControl = bayesianSigmaControl.sigmaMatrix1(:); % currently the TWO sigma version
bayesianSigmaMigraine = bayesianSigmaMigraine.sigmaMatrix1(:); 

figure; hold on;

% Plotting control data
scatter(SDTSigmaControl, bayesianSigmaControl, 20, ...
    'b', 'filled', 'MarkerFaceAlpha', 0.4);

% Plotting migraine data
scatter(SDTSigmaMigraine, bayesianSigmaMigraine, 20, ...
    'r', 'filled', 'MarkerFaceAlpha', 0.4);

% Adding reference line with slope 1
h = refline(1, 0);   % slope = 1, intercept = 0
h.Color = [0 0 0];   
h.LineWidth = 1.5;

% Labeling axes
xlabel('Old SDT \sigma');
ylabel('New Bayesian \sigma for two sigma model');
xlim([0 3.05]);
ylim([0 3.05]);
legend({'Controls', 'Migraines'}, 'Location', 'best');

title('SDT vs Bayesian Sigma Across All Conditions');





















