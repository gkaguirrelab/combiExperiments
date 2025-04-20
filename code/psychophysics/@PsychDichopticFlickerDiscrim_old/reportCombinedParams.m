function [psiParamsQuest, psiParamsFit, psiParamsCI, fVal] = reportCombinedParams(obj1, obj2, options)

% To determine params using the combined data from two psychometric
% objects, the high and low sides of the curve.

% Only perform bootstrapping if that argument is passed
arguments
    obj1
    obj2
    options.nBoots (1,1) = 0
    options.confInterval (1,1) = 0.8
    options.lb = []
    options.ub = []
end

% Grab some variables
questData = [obj1.questData, obj2.questData];
psiParamsDomainList = [obj1.psiParamsDomainList, obj2.psiParamsDomainList];
verbose = [obj1.verbose, obj2.verbose]; 

% The best guess at the params from Quest
max_values_posteriors = max(questData(1).posterior, questData(2).posterior);
psiParamsIndex = qpListMaxArg(max_values_posteriors);
psiParamsQuest = questData(1).psiParamsDomain(psiParamsIndex,:);

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

% Combine the trial data from the two objects

% Initialize an empty structure to hold the combined data
combinedTrialData = struct();

fields = fieldnames(questData(1).trialData);

% Loop through the fields and combine the values
for ii = 1:numel(fields)

    fieldName = fields{ii};

    fieldValue1 = [questData(1).trialData.(fieldName)];
    fieldValue2 = [questData(2).trialData.(fieldName)];

    combinedFieldValues = [fieldValue1, fieldValue2];

    for i = 1:length(combinedFieldValues)
        combinedTrialData(i).(fieldName) = combinedFieldValues(i);
    end

    combinedTrialData = (combinedTrialData)';

end

stimCounts = qpCounts(qpData(combinedTrialData),questData(1).nOutcomes);

% Obtain the fit
if options.nBoots>0
    % If we have asked for a CI on the psiParams, conduct a bootstrap in
    % which we resample with replacement from the set of trials in each
    % stimulus bin.
    trialDataSource = combinedTrialData;
    for bb=1:options.nBoots
        bootTrialData = trialDataSource;
        for ss=1:length(stimCounts)
            idxSource=find([combinedTrialData.stim]==stimCounts(ss).stim);
            idxBoot=datasample(idxSource,length(idxSource));
            bootTrialData(idxSource) = trialDataSource(idxBoot);
        end
        psiParamsFitBoot(bb,:) = qpFit(bootTrialData,questData(1).qpPF,psiParamsQuest,questData(1).nOutcomes,...
            'lowerBounds',options.lb,'upperBounds',options.ub);
    end
    psiParamsFitBoot = sort(psiParamsFitBoot);
    psiParamsFit = mean(psiParamsFitBoot);
    idxCI = round(((1-options.confInterval)/2*options.nBoots));
    psiParamsCI(1,:) = psiParamsFitBoot(idxCI,:);
    psiParamsCI(2,:) = psiParamsFitBoot(options.nBoots-idxCI,:);
else
    % No bootstrap. Just report the best fit params
    psiParamsFit = qpFit(combinedTrialData,questData(1).qpPF,psiParamsQuest,questData(1).nOutcomes,...
        'lowerBounds',options.lb,'upperBounds',options.ub);
    psiParamsCI = [];
end

% Get the error at the solution
fVal = qpFitError(psiParamsFit,stimCounts,questData(1).qpPF);

% Report these values
% if verbose
%     if obj1.simulateResponse
%         fprintf('Simulated parameters: %2.3f, %2.3f\n',obj1.simulatePsiParams);
%     end
%     fprintf('Max posterior QUEST+ parameters: %2.3f, %2.3f\n',psiParamsQuest);
%     fprintf('Maximum likelihood fit parameters: %2.3f, %2.3f\n', psiParamsFit);
% end


end
