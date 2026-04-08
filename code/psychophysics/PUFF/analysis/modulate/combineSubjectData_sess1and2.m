
clear

% Define the list of subjects. Data from subject BLNK_1010 was excluded
% post-hoc due to constant movement during recordings, which caused more
% than 50% loss of measurements in the majority of trials.
subjects = {'BLNK_1001','BLNK_1002','BLNK_1003','BLNK_1005','BLNK_1006',...
    'BLNK_1007','BLNK_1008','BLNK_1009','BLNK_1011','BLNK_1012'};

% Define the stimulus properties
directions = {'LightFlux','Mel','LMS','S_peripheral'};
directionLabels = {'LF','Mel','LMS','S'};
phaseLabels = {'OnOff','OffOn'};
contrastLabels = {'High','Low'};
phases = [0,pi];
contrasts =  {[0.4,0.4,0.4,0.4],[0.2,0.2,0.2,0.2]};
nTrials = 4;

% Define plot properties
directionColors = {[0 0 0],[0 1 1],[1 0.75 0],[0 0 1]};
directionLineColors = {'k','c',[1 0.75 0],'b'};

% Get the results from disk
% To check the results for each subject, set makePlotFlag to true, and
% then uncomment the pause and close all steps below
for ss = 1:length(subjects)
    results{ss} = processModulateVideos(subjects{ss},...
        'directions',directions,...
        'directionLabels',directionLabels,...
        'phaseLabels',phaseLabels,...
        'phases',phases,...
        'contrastLabels',contrastLabels,...
        'contrasts',contrasts,...
        'nTrials',nTrials,...
        'directionColors',directionColors,...
        'makePlotFlag',false);
    %{
    pause
    close all
    %}
end

% Get the across-subject average results
avgResults = acrossSubjectAverage(results);

% Plot the across-subject average responses
plotAvgResponses(avgResults,...
    'directionColors',directionColors)

% Get the individual subject fourier fits
fourierFitResults = obtainFourierResults(results);

% Plot a summary of the Fourier fits
plotSummaryPolar(fourierFitResults,...
    'directionColors',directionColors,...
    'directionLineColors',directionLineColors);

% Plot correlated individual variation in photoreceptor responses
plotIndividVariation(fourierFitResults,...
    'dirSets',{directionLabels([4,2]),directionLabels([4,3])},...
    'contrastLabel',contrastLabels{1});

% Get the photoreceptor integration model fits (and create a figure)
[p,fVals] = fitWeightModel(fourierFitResults);



% Save results
dropboxBaseDir = getpref('combiExperiments','dropboxBaseDir');
projectName = 'PuffLight';
experimentName = 'modulate';
saveDir = fullfile(dropboxBaseDir,'BLNK_analysis',projectName,experimentName,'FitData');

save([saveDir, '/fourierFitResultsSessions1and2.mat'], 'fourierFitResults', 'p', 'fVals', 'subjects');




