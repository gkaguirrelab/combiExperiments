% Code to compare the sigma values from the model with the SDT
% framework and the model with the Bayesian framework (one sigma version)

% Load SDT sigma data for controls
SDTSigmaControl = ['/Users/rubybouh/Documents/MATLAB/projects/' ...
    'combiExperiments/code/psychophysics/DCPT/sameDiffModel/modelSigmaCompare Data/12ControlSDTSigmaData'];
% Load SDT sigma data for migrainers
SDTSigmaMigraine = ['/Users/rubybouh/Documents/MATLAB/projects/' ...
    'combiExperiments/code/psychophysics/DCPT/sameDiffModel/modelSigmaCompare Data/11MigraineSDTSigmaData'];

% Load Bayesian sigma data for controls
bayesianSigmaControl = ['/Users/rubybouh/Documents/MATLAB/projects/' ...
    'combiExperiments/code/psychophysics/DCPT/sameDiffModel/modelSigmaCompare Data/12ControlBayesianSigmaData'];
% Load Bayesian sigma data for migrainers
bayesianSigmaMigraine = ['/Users/rubybouh/Documents/MATLAB/projects/' ...
    'combiExperiments/code/psychophysics/DCPT/sameDiffModel/modelSigmaCompare Data/11MigraineBayesianSigmaData'];

% Collapsing matrices into vectors
SDTSigmaControl = SDTSigmaControl(:);
SDTSigmaMigraine = SDTSigmaMigraine(:);
bayesianSigmaControl = bayesianSigmaControl(:);
bayesianSigmaMigraine = bayesianSigmaMigraine(:); 

figure; hold on;

% Plotting control data
scatter(SDTSigmaControl, bayesianSigmaControl, 20, ...
    'b', 'filled', 'MarkerFaceAlpha', 0.4);

% Plotting migraine data
scatter(SDTSigmaMigraine, bayesianSigmaMigraine, 20, ...
    'r', 'filled', 'MarkerFaceAlpha', 0.4);

% Labeling axes
xlabel('Old SDT \sigma');
ylabel('New Bayesian \sigma');
legend({'Controls', 'Migraines'}, 'Location', 'best');

title('SDT vs Bayesian Sigma Across All Conditions');





















