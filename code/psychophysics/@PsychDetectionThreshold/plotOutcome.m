function figHandle = plotOutcome(obj,visible)
% Create some figures that summarize the psychometric fitting

% Make the figure visible unless we pass "off"
if nargin==1
    visible='on';
end

% Grab some variables
questData = obj.questData;
testLogContrastSet = obj.testLogContrastSet;
nTrials = length(obj.questData.trialData);

% Get the Max Likelihood psi params, temporarily turning off verbosity
storeVerbose = obj.verbose;
obj.verbose = false;
[~, psiParamsFit] = obj.reportParams;
obj.verbose = storeVerbose;

% Set up a figure
figHandle = figure('visible',visible);
figuresize(750,250,'units','pt');

% First, plot the stimulus values used over trials
subplot(1,3,1);
hold on
plot(1:nTrials,[obj.questData.trialData.stim],'.r');
xlabel('trial number');
ylabel('log stimulus contrast')
title('stimulus by trial');

% Now the proportion correct for each stimulus type, and the psychometric
% function fit. Marker transparancy (and size) visualizes number of trials
% (more opaque -> more trials), while marker color visualizes percent
% correct (more red -> more correct).
subplot(1,3,2);
hold on

% Get the stim percent correct for each stimulus
stimCounts = qpCounts(qpData(questData.trialData),questData.nOutcomes);
stim = zeros(length(stimCounts),questData.nStimParams);
for cc = 1:length(stimCounts)
    stim(cc) = stimCounts(cc).stim;
    nTrials(cc) = sum(stimCounts(cc).outcomeCounts);
    pCorrect(cc) = stimCounts(cc).outcomeCounts(2)/nTrials(cc);
end

% Plot these
markerSizeIdx = discretize(nTrials,3);
markerSizeSet = [25,50,100];
for cc = 1:length(stimCounts)
    scatter(stim(cc),pCorrect(cc),markerSizeSet(markerSizeIdx(cc)),'o', ...
        'MarkerFaceColor',[pCorrect(cc) 0 1-pCorrect(cc)], ...
        'MarkerEdgeColor','k', ...
        'MarkerFaceAlpha',nTrials(cc)/max(nTrials));
    hold on
end

% Add the psychometric function
for cc = 1:length(testLogContrastSet)
    outcomes = obj.questData.qpPF(testLogContrastSet(cc),psiParamsFit);
    fitCorrect(cc) = outcomes(2);
end
plot(testLogContrastSet,fitCorrect,'-k')

% Add a marker for the threshold
outcomes = obj.questData.qpPF(psiParamsFit(1),psiParamsFit);
plot([psiParamsFit(1), psiParamsFit(1)],[0, outcomes(2)],':k')
plot([min(testLogContrastSet), psiParamsFit(1)],[outcomes(2), outcomes(2)],':k')

% Labels and range
ylim([-0.1 1.1]);
xlabel('log stimulus contrast')
ylabel('proportion correct');
title('Psychometric function');

% Entropy by trial
subplot(1,3,3);
hold on
plot(1:length(questData.entropyAfterTrial),questData.entropyAfterTrial,'.k');
xlabel('trial number');
ylabel('entropy');
title('Entropy by trial number')

% Add a supertitle
str = sprintf('Freq = %d Hz; params = [%2.3f, %2.3f, %2.3f, %2.3f]',...
    obj.testFreqHz,psiParamsFit);
sgtitle(str);

end