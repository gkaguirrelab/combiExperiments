function figHandle = plotOutcome(obj,visible)

if nargin==1
    visible='on';
end

% Grab some variables
questData = obj.questData;

% Transform the stimulus set to relative log space
refFreqSetRelative = obj.forwardTransformVals(obj.refFreqSetHz,obj.testFreqHz);

% Plot trial locations together with maximum likelihood fit. Point
% transparancy visualizes number of trials (more opaque -> more trials),
% while point color visualizes percent correct (more blue -> more R1).
figHandle = figure('visible',visible);
figuresize(750,250,'units','pt');

subplot(1,3,1);
hold on
stimCounts = qpCounts(qpData(questData.trialData),questData.nOutcomes);
stim = zeros(length(stimCounts),questData.nStimParams);
for cc = 1:length(stimCounts)
    stim(cc,:) = stimCounts(cc).stim;
    nTrials(cc) = sum(stimCounts(cc).outcomeCounts);
    pChooseR2(cc) = stimCounts(cc).outcomeCounts(2)/nTrials(cc);
end
markerSizeIdx = discretize(nTrials,3);
markerSizeSet = [12,25,50];
for cc = 1:length(stimCounts)
    scatter(stim(cc,2),stim(cc,1),markerSizeSet(markerSizeIdx(cc)),'o', ...
        'MarkerFaceColor',[pChooseR2(cc) 0 1-pChooseR2(cc)], ...
        'MarkerEdgeColor','k', ...
        'MarkerFaceAlpha',nTrials(cc)/max(nTrials));
    hold on
end
axis square
xlim([-1 1]);
ylim([-1 1]);
xlabel('ref2 [difference in log freq from test]');
ylabel('ref1 [difference in log freq from test]');
set(gca, 'YDir','reverse')
title('red choose R2; blue choose R1')

subplot(1,3,2);
hold on
% Get the Max Likelihood psi params
storeVerbose = obj.verbose;
obj.verbose = false;
[~, psiParamsFit] = obj.reportParams;
obj.verbose = storeVerbose;

% Plot the psychometric matrix
for r1 = refFreqSetRelative
    for r2 = refFreqSetRelative
        pChooseR2 = qpPFJoganStocker([r1,r2],psiParamsFit);
        h = scatter(r2,r1,25,'o','MarkerEdgeColor','none','MarkerFaceColor',[pChooseR2(2) 0 pChooseR2(1)],...
            'MarkerFaceAlpha',1,'MarkerEdgeAlpha',1);
    end
end
axis square
xlim([-1 1]);
ylim([-1 1]);
xlabel('ref2 [difference in log freq from test]');
ylabel('ref1 [difference in log freq from test]');
set(gca, 'YDir','reverse')
title('red choose R2; blue choose R1')

subplot(1,3,3);
hold on
plot(1:length(questData.entropyAfterTrial),questData.entropyAfterTrial,'.k');
axis square
xlabel('trial number');
ylabel('entropy');
title('Entropy by trial number')

% Add a supertitle
str = sprintf(...
    ['ref contrast db = ' obj.refContrastLabel ...
    '; test contrast db = ' obj.testContrastLabel ...
    '; test freq = %d Hz; params = [%2.3f, %2.3f, %2.3f]'],...
    obj.testFreqHz,psiParamsFit);
sgtitle(str);

end