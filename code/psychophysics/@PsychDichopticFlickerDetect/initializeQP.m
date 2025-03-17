function initializeQP(obj)

% Pull out some information from the obj
simulateResponse = obj.simulateResponse;
verbose = obj.verbose;

% Handle simulation and the outcome function
if simulateResponse
    simulatePsiParams = obj.simulatePsiParams;
    qpOutcomeF = @(x) qpSimulatedObserver(x,obj.psychometricFuncHandle,simulatePsiParams);
else
    qpOutcomeF = [];
end

% Create the Quest+ varargin
qpKeyVals = { ...
    'stimParamsDomainList',{obj.stimParamsDomainList}, ...
    'psiParamsDomainList',obj.psiParamsDomainList, ...
    'qpPF',obj.psychometricFuncHandle, ...
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

end