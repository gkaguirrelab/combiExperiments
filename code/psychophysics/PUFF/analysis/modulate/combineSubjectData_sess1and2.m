
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
phaseFileNames = {'0.00','3.14'};
contrasts =  {[0.4,0.4,0.4,0.4],[0.2,0.2,0.2,0.2]};
nTrials = 4;

% Define plot properties
directionColors = {[0 0 0],[0 1 1],[1 0.75 0],[0 0 1]};
directionLineColors = {'k','c',[1 0.75 0],'b'};

% Obtain the behavioral performance. We exclude BLINK_1011, as there seems
% to have been some technical error that resulted in zero detected trials.
goodSubs = ~strcmp(subjects,'BLNK_1011');
[nDetectTrials,proportionDetect,trialIdxWithMissedDetections] = ...
    reportModulateBehavPerformance(subjects(goodSubs),directions,contrasts,phases);
nMisses = sum(cell2mat(cellfun(@(x) sum(x),trialIdxWithMissedDetections(:),'UniformOutput',false)));
fprintf('On average, each participant was presented with a total of %2.0f trials across all conditions.\n',sum(nDetectTrials(:),'omitmissing')/sum(goodSubs));
fprintf('Out of the total of %d trials across all subjects, only %d trials were missed.\n',sum(nDetectTrials(:),'omitmissing'),nMisses);

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

% Report the ipRGC photoreceptor weights for the high-contrast stimulus set


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




