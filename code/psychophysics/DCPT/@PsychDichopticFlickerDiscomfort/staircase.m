function stimParam = staircase(obj,currTrialIdx)
% Implement a typical staircase procedure for selecting the next stimulus
% parameter. For example, the stimulus level is increased by one step if
% the observer makes one mistake (1 up) and is decreased by one step if the
% observer makes three consecutive correct responses (3 down)


% Get the staircase rule we are following
staircaseRule = obj.staircaseRule;
nUp = staircaseRule(1); nDown = staircaseRule(2);

% Get the stimParamsDomainList
stimParamsDomainList = obj.stimParamsDomainList;

% Sort the abs(stimParamsDomainList) from largest to smallest, just in case
% it is not in this order
[~,sortOrder] = sort(abs(stimParamsDomainList),'descend');
sortedStimParamsDomainList = stimParamsDomainList(sortOrder);

% Get the trialData
trialData = obj.questData.trialData;

% If we are on the first trial, use a starting point that is 1/4 from the
% most intense option in the sortedStimParamsDomainList
if currTrialIdx==1
    stimIdx = round(length(sortedStimParamsDomainList)*0.25);
    stimParam = sortedStimParamsDomainList(stimIdx);
    return
end

% Get the last stimParam and the sequence of correct/incorrect responses
stimParamLast = trialData(end).stim;
stimParamVector = [trialData.stim];
correctResponses = [trialData.correct];

% Figure out the index within the stimParamsDomainList that corresponds to
% stimParamLast
stimIdx = find(sortedStimParamsDomainList==stimParamLast);

% Special case if too few trials have elapsed to make an up adjustment
if currTrialIdx <= nUp
    stimParam = stimParamLast;
    return
end

% Check for the "up" condition that results from the observer making a
% series of mistakes at this stimulus intensity level
if ~any(correctResponses(end-nUp+1:end)) && isscalar(unique(stimParamVector(end-nUp+1:end)))
    % If we are already at the max stimulus, no further action to take
    if stimIdx == 1
        stimParam = stimParamLast;
        return
    end
    % Otherwise, increase the intensity of the stimulus
    stimParam = sortedStimParamsDomainList(stimIdx-1);
    return
end

% Special case if too few trials have elapsed to make an down adjustment
if currTrialIdx <= nDown
    stimParam = stimParamLast;
    return
end

% Check for the "down" condition that results from the observer making a
% series of correct responses at this stimulus intensity level
if all(correctResponses(end-nDown+1:end)) && isscalar(unique(stimParamVector(end-nDown+1:end)))
    % If we are already at the min stimulus, no further action to take
    if stimIdx == length(sortedStimParamsDomainList)
        stimParam = stimParamLast;
        return
    end
    % Otherwise, decrease the intensity of the stimulus
    stimParam = sortedStimParamsDomainList(stimIdx+1);
    return
end

% If we have reached this point, we make no change in the stimulus
stimParam = stimParamLast;

end