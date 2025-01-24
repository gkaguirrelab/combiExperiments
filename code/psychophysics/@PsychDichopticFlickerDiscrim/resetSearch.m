function resetSearch(obj)

% Check that we have actually acquired some trials
if isempty(obj.questData)
    return
end
if isempty(obj.questData.trialData)
    return
end

% Pull out some information from the obj
verbose = obj.verbose;

% Replace the current posterior and expectedNextEntropiesByStim with the
% initial values
obj.questData.posterior  = ...
    obj.questData.initialPosterior;
obj.questData.expectedNextEntropiesByStim  = ...
    obj.questData.initialExpectedNextEntropiesByStim;

% Alert the user
if verbose
    fprintf('Reset search\n')
end


end