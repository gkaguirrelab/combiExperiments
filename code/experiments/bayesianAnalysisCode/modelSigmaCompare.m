% Code to compare the sigma values from the model with the SDT
% framework and the model with the Bayesian framework (one sigma version)

% Defining the directory 
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir = 'FLIC_analysis';
projectName = 'dichopticFlicker';
experimentName = 'sigmaData';
dataDir = fullfile(dropBoxBaseDir, dropBoxSubDir, projectName, experimentName); 

% Load SDT sigma data for controls
SDTSigmaControlFile = fullfile(dataDir, '/12ControlSDTSigmaData.mat');
SDTSigmaControl = load(SDTSigmaControlFile, 'sigmaMatrix');
% Load SDT sigma data for migrainers
SDTSigmaMigraineFile = fullfile(dataDir, '/11MigraineSDTSigmaData.mat');
SDTSigmaMigraine = load(SDTSigmaControlFile, 'sigmaMatrix');

% Load Bayesian TWO sigma data for controls
bayesianSigmaControlFile = fullfile(dataDir, '/14ControlBayesianTwoSigmaData.mat');
bayesianSigmaControl = load(bayesianSigmaControlFile, 'sigmaMatrix1'); 
% Load Bayesian TWO sigma data for migrainers
bayesianSigmaMigraineFile = fullfile(dataDir, '/12MigraineBayesianTwoSigmaData.mat');
bayesianSigmaMigraine = load(bayesianSigmaMigraineFile, 'sigmaMatrix1'); 

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





















