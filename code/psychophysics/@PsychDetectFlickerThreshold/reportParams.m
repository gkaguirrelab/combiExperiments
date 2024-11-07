function [psiParamsQuest, psiParamsFit, psiParamsCI, fVal] = reportParams(obj,options)

% Only perform bootstrapping if that argument is passed
arguments
    obj
    options.nBoots (1,1) = 0
    options.confInterval (1,1) = 0.8
    options.lb = []
    options.ub = []
end

% Grab some variables
questData = obj.questData;
psiParamsDomainList = obj.psiParamsDomainList;
verbose = obj.verbose;

% The best quess at the params from Quest
psiParamsIndex = qpListMaxArg(questData.posterior);
psiParamsQuest = questData.psiParamsDomain(psiParamsIndex,:);

% Maximum likelihood fit. Create bounds from psiParamsDomainList
if isempty(options.lb)
    for ii=1:length(psiParamsDomainList)
        options.lb(ii) = min(psiParamsDomainList{ii});
    end
end
if isempty(options.ub)
    for ii=1:length(psiParamsDomainList)
        options.ub(ii) = max(psiParamsDomainList{ii});
    end
end

% We require the stimCounts below
stimCounts = qpCounts(qpData(questData.trialData),questData.nOutcomes);

% Obtain the fit
if options.nBoots>0
    % If we have asked for a CI on the psiParams, conduct a bootstrap in
    % which we resample with replacement from the set of trials in each
    % stimulus bin.
    trialDataSource=questData.trialData;
    for bb=1:options.nBoots
        bootTrialData = trialDataSource;
        for ss=1:length(stimCounts)
            idxSource=find([questData.trialData.stim]==stimCounts(ss).stim);
            idxBoot=datasample(idxSource,length(idxSource));
            bootTrialData(idxSource)=trialDataSource(idxBoot);
        end
        psiParamsFitBoot(bb,:) = qpFit(bootTrialData,questData.qpPF,psiParamsQuest,questData.nOutcomes,...
            'lowerBounds',options.lb,'upperBounds',options.ub);
    end
    psiParamsFitBoot = sort(psiParamsFitBoot);
    psiParamsFit = mean(psiParamsFitBoot);
    idxCI = round(((1-options.confInterval)/2*options.nBoots));
    psiParamsCI(1,:) = psiParamsFitBoot(idxCI,:);
    psiParamsCI(2,:) = psiParamsFitBoot(options.nBoots-idxCI,:);
else
    % No bootstrap. Just report the best fit params
    psiParamsFit = qpFit(questData.trialData,questData.qpPF,psiParamsQuest,questData.nOutcomes,...
        'lowerBounds',options.lb,'upperBounds',options.ub);
    psiParamsCI = [];
end

% Get the error at the solution
fVal = qpFitError(psiParamsFit,stimCounts,questData.qpPF);

% Report these values
if verbose
    if obj.simulateResponse
        fprintf('Simulated parameters: %2.3f, %2.3f, %2.3f, %2.3f\n',obj.simulatePsiParams);
    end
    fprintf('Max posterior QUEST+ parameters: %2.3f, %2.3f, %2.3f, %2.3f\n',psiParamsQuest);
    fprintf('Maximum likelihood fit parameters: %2.3f, %2.3f, %2.3f, %2.3f\n', psiParamsFit);
end


end