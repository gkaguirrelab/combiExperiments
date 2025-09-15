function figHandle = plotOutcomeCombined(obj,objFileCellArray,visible)
% Create some figures that summarize the psychometric fitting

% Load a set of psychometric objects specified in the objFileCellArray and
% concatenate their trialData fields. Note that you must pass the filepath
% to this object itself if you wish to use it in the combo data.
comboTrialData = [];
for ii = 1:length(objFileCellArray)
    load(objFileCellArray{ii},'psychObj');
    comboTrialData = [comboTrialData; psychObj.questData.trialData];
end

% Make the figure visible unless we pass "off"
if nargin==2
    visible='on';
end

% Grab some variables; use the combo data for the quest data. 
questData = obj.questData;
questData.trialData = comboTrialData;
stimParamsDomainList = obj.stimParamsDomainList;
nTrials = length(obj.questData.trialData);

% Get the Max Likelihood psi params, temporarily turning off verbosity.
lb = cellfun(@(x) min(x),obj.psiParamsDomainList);
ub = cellfun(@(x) max(x),obj.psiParamsDomainList);
ub(3) = 2;
storeVerbose = obj.verbose;
obj.verbose = false;
[~, psiParamsFit] = obj.reportParams('lb',lb,'ub',ub,'questData',questData);
obj.verbose = storeVerbose;

% Set up a figure
figHandle = figure('visible',visible);
figuresize(250,250,'units','pt');

% Now the proportion "respond different" for each stimulus type, and the
% psychometric function fit. Marker transparancy (and size) visualizes
% number of trials (more opaque -> more trials), while marker color
% visualizes percent correct (more red -> more respond yes).
hold on

% Get the proportion respond "different" for each stimulus
stimCounts = qpCounts(qpData(questData.trialData),questData.nOutcomes);
stim = zeros(length(stimCounts),questData.nStimParams);
for cc = 1:length(stimCounts)
    stim(cc) = stimCounts(cc).stim;
    nTrials(cc) = sum(stimCounts(cc).outcomeCounts);
    pRespondDifferent(cc) = stimCounts(cc).outcomeCounts(2)/nTrials(cc);
end

% Plot these. Use a different marker for the 0 dB case
markerSizeIdx = discretize(nTrials(2:end),3);
markerSizeIdx = [3 markerSizeIdx];
markerSizeSet = [25,50,100];
for cc = 1:length(stimCounts)
    if cc == 1
        scatter(stim(cc),pRespondDifferent(cc),markerSizeSet(markerSizeIdx(cc)),'diamond', ...
            'MarkerFaceColor',[pRespondDifferent(cc) 0 1-pRespondDifferent(cc)], ...
            'MarkerEdgeColor','k', ...
            'MarkerFaceAlpha',nTrials(cc)/max(nTrials));
    else
        scatter(stim(cc),pRespondDifferent(cc),markerSizeSet(markerSizeIdx(cc)),'o', ...
            'MarkerFaceColor',[pRespondDifferent(cc) 0 1-pRespondDifferent(cc)], ...
            'MarkerEdgeColor','k', ...
            'MarkerFaceAlpha',nTrials(cc)/max(nTrials));
    end
    hold on
end

% Add the psychometric function
for cc = 1:length(stimParamsDomainList)
    outcomes = obj.questData.qpPF(stimParamsDomainList(cc),psiParamsFit);
    fitRespondYes(cc) = outcomes(2);
end
plot(stimParamsDomainList,fitRespondYes,'-k')

% Labels and range
ylim([-0.1 1.1]);
xlabel('stimulus difference [dB]')
ylabel('proportion respond different')
title('Psychometric function');

% Add a supertitle
str = sprintf('Ref freq = %d Hz; [fpRate,τ,γ] = [%2.3f,%2.3f,%2.3f]',...
    obj.refFreqHz,psiParamsFit);
title(str);

end