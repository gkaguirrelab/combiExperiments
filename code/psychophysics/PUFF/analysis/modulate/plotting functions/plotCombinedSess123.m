% Code to plot amplitude of Mel and L-M responses for participants who did
% both experiments

clear

% set up paths
dropboxBaseDir = getpref('combiExperiments','dropboxBaseDir');
projectName = 'PuffLight';
experimentName = 'modulate';
fitDir = fullfile(dropboxBaseDir,'BLNK_analysis',projectName,experimentName,'FitData');

% set up some variables
directionLabels = {'Mel','LminusM'};
contrastLabels = {'Max'};
contrasts = {[0.4, 0.1]};

%load fourier results
fourierFitResultsSess3 = load([fitDir, '/fourierFitResultsSession3.mat']);
fourierFitResultsSess1and2 = load([fitDir, '/fourierFitResultsSessions1and2.mat']);

% identify overlapping subjects
subs12 = fourierFitResultsSess1and2.subjects;
subs3  = fourierFitResultsSess3.subjects;

% 'stable' preserves the order of the first input, 
% 'ia' returns indices for subs12, 'ib' returns indices for subs3
[commonSubjects, ia, ib] = intersect(subs12, subs3, 'stable');

% make a new struct with data for Mel and LminusM from overlapping subjects
conL = contrastLabels{1}; 

overlappingResults = struct();
overlappingResults.subjects = commonSubjects;

% Map S (From Session 3 - index 'ib')
% We ensure the field name matches 'conL' (e.g., 'Max' or 'High')
overlappingResults.S.(conL).amplitude    = fourierFitResultsSess3.fourierFitResults.S.Max.amplitude(ib);
overlappingResults.S.(conL).phase        = fourierFitResultsSess3.fourierFitResults.S.Max.phase(ib);
overlappingResults.S.(conL).amplitudeSEM = fourierFitResultsSess3.fourierFitResults.S.Max.amplitudeSEM(ib);

% Map LminusM (From Session 3 - index 'ib')
overlappingResults.LminusM.(conL).amplitude    = fourierFitResultsSess3.fourierFitResults.LminusM.Max.amplitude(ib);
overlappingResults.LminusM.(conL).phase        = fourierFitResultsSess3.fourierFitResults.LminusM.Max.phase(ib);
overlappingResults.LminusM.(conL).amplitudeSEM = fourierFitResultsSess3.fourierFitResults.LminusM.Max.amplitudeSEM(ib);

% Map Mel (From Session 1&2 - index 'ia')
% Check if Sess 1&2 uses '.Max' or '.High' internally and match it here:
overlappingResults.Mel.(conL).amplitude    = fourierFitResultsSess1and2.fourierFitResults.Mel.High.amplitude(ia);
overlappingResults.Mel.(conL).phase        = fourierFitResultsSess1and2.fourierFitResults.Mel.High.phase(ia);
overlappingResults.Mel.(conL).amplitudeSEM = fourierFitResultsSess1and2.fourierFitResults.Mel.High.amplitudeSEM(ia);


% Plot correlated individual variation in photoreceptor responses
plotIndividVariation(overlappingResults,...
    'dirSets',{directionLabels([1,2])},...
    'contrastLabel',contrastLabels{1});