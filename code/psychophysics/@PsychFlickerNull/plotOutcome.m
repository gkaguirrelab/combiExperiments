function figHandle = plotOutcome(obj,visible)
% Create some figures that summarize the psychometric fitting

% Make the figure visible unless we pass "off"
if nargin==1
    visible='on';
end

% Grab some variables
questData = obj.questData;
stimTestSet = obj.stimTestSet;
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
ylabel('stimulus setting')
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
    if obj.adjustHighSettings
        plotSymbol = 'o';
    else
        plotSymbol = 's';
    end
    scatter(stim(cc),pCorrect(cc),markerSizeSet(markerSizeIdx(cc)),plotSymbol, ...
        'MarkerFaceColor',[pCorrect(cc) 0 1-pCorrect(cc)], ...
        'MarkerEdgeColor','k', ...
        'MarkerFaceAlpha',nTrials(cc)/max(nTrials));
    hold on
end

% Add the psychometric function
fitTestSet = min(stimTestSet):0.01:max(stimTestSet);
for cc = 1:length(fitTestSet)
    outcomes = obj.questData.qpPF(fitTestSet(cc),psiParamsFit);
    fitCorrect(cc) = outcomes(2);
end
plot(fitTestSet,fitCorrect,'-k')

% Add a marker for the threshold
outcomes = obj.questData.qpPF(psiParamsFit(1),psiParamsFit);
plot([psiParamsFit(1), psiParamsFit(1)],[0, outcomes(2)],':k')
plot([min(stimTestSet), psiParamsFit(1)],[outcomes(2), outcomes(2)],':k')

% Labels and range
ylim([0 1.0]);
xlim([min(obj.psiParamsDomainList{1}) max(obj.psiParamsDomainList{1})]);
xlabel('stimulus setting')
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
str = sprintf('params = [%2.3f, %2.3f, %2.3f]',...
    psiParamsFit);
sgtitle(str);

end