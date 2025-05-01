function figHandle = plotOutcome(obj,visible)
% Create some figures that summarize the psychometric fitting

% Make the figure visible unless we pass "off"
if nargin==1
    visible='on';
end

% Grab some variables
questData = obj.questData;
stimParamsDomainList = obj.stimParamsDomainList;
nTrials = length(obj.questData.trialData);

% Get the Max Likelihood psi params, temporarily turning off verbosity.
lb = cellfun(@(x) min(x),obj.psiParamsDomainList);
ub = cellfun(@(x) max(x),obj.psiParamsDomainList);
storeVerbose = obj.verbose;
obj.verbose = false;
[~, psiParamsFit] = obj.reportParams('lb',lb,'ub',ub);
obj.verbose = storeVerbose;

% Set up a figure
figHandle = figure('visible',visible);
figuresize(750,250,'units','pt');

% First, plot the stimulus values used over trials
subplot(1,3,1);
hold on
plot(1:nTrials,[obj.questData.trialData.stim],'.r');
xlabel('trial number');
ylabel('stimulus difference [dB]')
title('stimulus by trial');

% Now the proportion correct for each stimulus type, and the psychometric
% function fit. Marker transparancy (and size) visualizes number of trials
% (more opaque -> more trials), while marker color visualizes percent
% correct (more red -> more correct).
subplot(1,3,2);
hold on

% Get the proportion selected "test" for each stimulus
stimCounts = qpCounts(qpData(questData.trialData),questData.nOutcomes);
stim = zeros(length(stimCounts),questData.nStimParams);
for cc = 1:length(stimCounts)
    stim(cc) = stimCounts(cc).stim;
    nTrials(cc) = sum(stimCounts(cc).outcomeCounts);
    pSelectTest(cc) = stimCounts(cc).outcomeCounts(2)/nTrials(cc);
end


% Plot these
markerSizeIdx = discretize(nTrials,3);
markerSizeSet = [25,50,100];
for cc = 1:length(stimCounts)
    scatter(stim(cc),pSelectTest(cc),markerSizeSet(markerSizeIdx(cc)),'o', ...
        'MarkerFaceColor',[pSelectTest(cc) 0 1-pSelectTest(cc)], ...
        'MarkerEdgeColor','k', ...
        'MarkerFaceAlpha',nTrials(cc)/max(nTrials));
    hold on
end

% Add the psychometric function
for cc = 1:length(stimParamsDomainList)
    outcomes = obj.questData.qpPF(stimParamsDomainList(cc),psiParamsFit);
    fitCorrect(cc) = outcomes(2);
end
plot(stimParamsDomainList,fitCorrect,'-k')

% Add a marker for the 50% point
outcomes = obj.questData.qpPF(psiParamsFit(1),psiParamsFit);
plot([psiParamsFit(1), psiParamsFit(1)],[0, outcomes(2)],':k')
plot([min(stimParamsDomainList), psiParamsFit(1)],[0.5 0.5],':k')

% Labels and range
ylim([-0.1 1.1]);
xlabel('stimulus difference [dB]')
ylabel('proportion correct')
title('Psychometric function');

% Entropy by trial
subplot(1,3,3);
hold on
plot(1:length(questData.entropyAfterTrial),questData.entropyAfterTrial,'.k');
xlabel('trial number');
ylabel('entropy');
title('Entropy by trial number')

% Add a supertitle
str = sprintf('Ref freq = %d Hz; [μ,σ,λ] = [%2.3f,%2.3f,%2.3f]',...
    obj.refFreqHz,psiParamsFit);
sgtitle(str);

end