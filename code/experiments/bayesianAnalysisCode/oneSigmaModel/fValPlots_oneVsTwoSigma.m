% SETUP - defining variables and choosing subject IDs

% VARIABLES TO CHANGE
% Choose whether you want to save the sigma data in a .mat file
saveData = true; 
% Choose whether you want to run migrainer or control subjects
control = false; 
% Choose whether you want to implement the non-linear constraint
nonLinearConstraint = true; 

% The rest of the code does not need to be changed
% Defining the directory
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir = 'FLIC_data';
projectName = 'combiLED';
experimentName = 'DCPT_SDT';

% Define subjects + parameters
if control   % control subject IDs
    subjectID = {'FLIC_0013', 'FLIC_0015', 'FLIC_0017', ...
        'FLIC_0018', 'FLIC_0019','FLIC_0020', 'FLIC_0021', 'FLIC_0022', 'FLIC_0027', ...
        'FLIC_0028','FLIC_0039', 'FLIC_0042', 'FLIC_0049', 'FLIC_0050', 'FLIC_0051'};
else   % migrainer subject IDs
    subjectID = {'FLIC_1016','FLIC_1029','FLIC_1030','FLIC_1031','FLIC_1032', ...
        'FLIC_1034','FLIC_1035','FLIC_1036','FLIC_1038', 'FLIC_1041', 'FLIC_1043',...
        'FLIC_1044', 'FLIC_1046', 'FLIC_1047', 'FLIC_1048'};
end

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
nSubj = length(subjectID);

%% Compare one and two sigma parameter models, for individual subject fits
% Create side by side fVal plots

% Using the entire sets of nSubj x 4 F values, from migrainers and controls

% Extract by group (keep other dims, then flatten)
fValsControl = fValMatrix(1,:,:,:);
fValsMigraine = fValMatrix(2,:,:,:);

% Convert from cell → numeric and flatten
fValsControl = cell2mat(fValsControl(:));
fValsMigraine = cell2mat(fValsMigraine(:));

% Define shared bin edges
% Use combined data to ensure both histograms share the same scale
allData = [fValsMigraine; fValsControl];
edges = linspace(min(allData), max(allData), 20);

% Overlaid histogram so fancy so pretty
figure; hold on;
h1 = histogram(fValsMigraine, edges, 'FaceAlpha', 0.5, 'EdgeColor', 'none');
h2 = histogram(fValsControl,  edges, 'FaceAlpha', 0.5, 'EdgeColor', 'none');

xlabel('Negative log-likelihood (fVal)');
ylabel('Count');
legend({'Migrainers', 'Controls'});
title('Model fit quality across conditions when sigmaTest = sigmaRef');
box off;

%% Compare one and two sigma parameter models, for super subject fits
% Create side by side fVal plots