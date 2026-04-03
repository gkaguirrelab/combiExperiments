% SETUP - defining variables and choosing subject IDs

% The rest of the code does not need to be changed
% Defining the directory
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir = 'FLIC_analysis';
projectName = 'dichopticFlicker';
experimentName = 'sigmaData';

% Define experimental condition variables 
modDirection = 'LightFlux';
NDLabel = {'3x0', '0x5'};   % {'3x0', '0x5'}
stimParamLabels = {'low', 'hi'}; % {'low', 'hi'}
refFreqHz = logspace(log10(10),log10(30),5);  % logspace(log10(10),log10(30),5)
targetPhotoContrast = {'0x1','0x3'};  % {'0x1','0x3'}

% Define length variables
nFreqs = length(refFreqHz);
nContrasts = length(targetPhotoContrast);
nLightLevels = length(NDLabel); 

%% Compare one and two sigma parameter models, for individual subject fits
% Create side by side fVal plots

% Using the entire sets of nSubj x 4 F values, from migrainers and controls

% Load the individual subject fit sigma vals
fileStem = fullfile(dropBoxBaseDir, dropBoxSubDir, projectName, experimentName);
oneSigmaControls = load([fileStem '/15Control_individualSigmaFits_oneSigma.mat'], ...
    'fValMatrix').fValMatrix; 
oneSigmaMigrainers = load([fileStem '/15Migrainer_individualSigmaFits_oneSigma.mat'], ...
    'fValMatrix').fValMatrix; 

twoSigmaControls = load([fileStem '/15Control_individualSigmaFitsConstrained.mat'], ...
    'fValMatrix').fValMatrix; 
twoSigmaMigrainers = load([fileStem '/15Migrainer_individualSigmaFitsConstrained.mat'], ...
    'fValMatrix').fValMatrix; 

% Flatten to vectors
oneCtrl = oneSigmaControls(:);
oneMig  = oneSigmaMigrainers(:);

twoCtrl = twoSigmaControls(:);
twoMig  = twoSigmaMigrainers(:);

% Define bin edges across all data
allData = [oneCtrl; oneMig; twoCtrl; twoMig];
edges = linspace(min(allData), max(allData), 20);

% Plot
figure;

% One sigma subplot
subplot(1,2,1); hold on;
histogram(oneCtrl, edges, 'FaceAlpha', 0.5, 'EdgeColor', 'none');
histogram(oneMig,  edges, 'FaceAlpha', 0.5, 'EdgeColor', 'none');

xlabel('Negative log-likelihood (fVal)');
ylabel('Count');
ylim([0 100]);
title('One-sigma model fit quality across individual condition fits');
legend({'Controls', 'Migrainers'});
box off;

% Two sigma subplot
subplot(1,2,2); hold on;
histogram(twoCtrl, edges, 'FaceAlpha', 0.5, 'EdgeColor', 'none');
histogram(twoMig,  edges, 'FaceAlpha', 0.5, 'EdgeColor', 'none');

xlabel('Negative log-likelihood (fVal)');
ylabel('Count');
ylim([0 100]);
title('Two-sigma model fit quality across individual condition fits');
legend({'Controls', 'Migrainers'});
box off;

%% Compare one and two sigma parameter models, for super subject fits
% Create side by side fVal plots

% Load the super subject fit sigma vals
% Note that the structure of this data is different from the individual fits
fileStem = fullfile(dropBoxBaseDir, dropBoxSubDir, projectName, experimentName);

% One sigma data
oneSigmas = load([fileStem '/30_superSubjSigmaFits_oneSigma.mat'], ...
    'fValMatrix').fValMatrix; 
% Extract by group
oneSigma_fValsControlCells  = oneSigmas(1,:,:,:);
oneSigma_fValsMigraineCells = oneSigmas(2,:,:,:);
% Flatten
oneSigma_fValsControl  = cell2mat(oneSigma_fValsControlCells(:));
oneSigma_fValsMigraine = cell2mat(oneSigma_fValsMigraineCells(:));

% Two sigma data
twoSigmas = load([fileStem '/30_superSubjSigmaFitsConstrained.mat'], ...
    'fValMatrix').fValMatrix; 
% Extract by group
twoSigma_fValsControlCells  = twoSigmas(1,:,:,:);
twoSigma_fValsMigraineCells = twoSigmas(2,:,:,:);
% Flatten
twoSigma_fValsControl  = cell2mat(twoSigma_fValsControlCells(:));
twoSigma_fValsMigraine = cell2mat(twoSigma_fValsMigraineCells(:));

% Combine all fVals to determine shared bin edges
allFvals = [oneSigma_fValsControl; oneSigma_fValsMigraine; ...
            twoSigma_fValsControl; twoSigma_fValsMigraine];

% Define shared edges
edges = linspace(min(allFvals), max(allFvals), 20);

% Create side-by-side plots
figure;

% One sigma subplot
subplot(1,2,1); hold on;
histogram(oneSigma_fValsControl, edges, 'FaceAlpha', 0.5, 'EdgeColor','none');
histogram(oneSigma_fValsMigraine, edges, 'FaceAlpha', 0.5, 'EdgeColor','none');
xlabel('Negative log-likelihood (fVal)');
ylabel('Count');
ylim([0 5]);
legend({'Controls', 'Migrainers'});
title('One-sigma super-subject fit quality');
box off;

% Two sigma subplot
subplot(1,2,2); hold on;
histogram(twoSigma_fValsControl, edges, 'FaceAlpha', 0.5, 'EdgeColor','none');
histogram(twoSigma_fValsMigraine, edges, 'FaceAlpha', 0.5, 'EdgeColor','none');
xlabel('Negative log-likelihood (fVal)');
ylabel('Count');
ylim([0 5]);
legend({'Controls', 'Migrainers'});
title('Two-sigma super-subject fit quality');
box off;