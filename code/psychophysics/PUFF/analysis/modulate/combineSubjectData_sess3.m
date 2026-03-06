close all
clear

% Define the list of subjects. Data from subject BLNK_1010 was excluded
% post-hoc due to constant movement during recordings, which caused more
% than 50% loss of measurements in the majority of trials.
subjects = {'BLNK_1001','BLNK_1005','BLNK_1008','BLNK_1009','BLNK_1011',...
    'BLNK_1013','BLNK_1014'};

% Define the stimulus properties
directions = {'S_peripheral','LminusM_MelSilent_peripheral'};
directionLabels = {'S','LminusM'};
phaseLabels = {'OnOff','OffOn'};
contrastLabels = {'Max'};
phases = [0,pi];
contrasts = {[0.7,0.1]};
nTrials = 8;

% Define plot properties
directionColors = {[0 0 1],[1 0 0]};
directionLineColors = {'b','r'};

% Get the results from disk
for ss = 1:length(subjects)
    % To check the results for each subject, set makePlotFlag to true, and
    % then uncomment the pause and close all steps below
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

% Get the individual subject fourier fits
fourierFitResults = obtainFourierResults(results);

% A summary plot of the Fourier fits
summaryPolarPlot(fourierFitResults,...
    'directionColors',directionColors,...
    'directionLineColors',directionLineColors);

% Plot the across-subject average responses
plotAvgResponses(avgResults,...
    'directionColors',directionColors)





