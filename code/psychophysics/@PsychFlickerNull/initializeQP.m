function initializeQP(obj)

% Pull out some information from the obj
stimTestSet = obj.stimTestSet;
psiParamsDomainList = obj.psiParamsDomainList;
simulateResponse = obj.simulateResponse;
verbose = obj.verbose;

% Handle simulation and the outcome function
if simulateResponse
    simulatePsiParams = obj.simulatePsiParams;
    qpOutcomeF = @(x) qpSimulatedObserver(x,@qpInvertedNormal,simulatePsiParams);
else
    qpOutcomeF = [];
end

% Create the Quest+ varargin
qpKeyVals = { ...
    'stimParamsDomainList',{stimTestSet}, ...
    'psiParamsDomainList',psiParamsDomainList, ...
    'qpPF',@qpInvertedNormal, ...
    'qpOutcomeF',qpOutcomeF, ...
    'nOutcomes', 2, ...
    'verbose',verbose};

% Alert the user
if verbose
    fprintf('Initializing Quest+\n')
end

% Perform the initialize operation
obj.questData = qpInitialize(qpKeyVals{:});

% Store the initial values of expectedNextEntropiesByStim and the posterior
obj.questData.initialPosterior = ...
    obj.questData.posterior;
obj.questData.initialExpectedNextEntropiesByStim = ...
    obj.questData.expectedNextEntropiesByStim;

% Add the invalidResponseTrials field
obj.questData.invalidResponseTrials = [];

end