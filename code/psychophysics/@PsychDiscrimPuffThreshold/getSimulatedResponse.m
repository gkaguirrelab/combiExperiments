function [intervalChoice, responseTimeSecs] = getSimulatedResponse(obj,qpStimParams,testInterval)

% Get the simulated choice of ref1 or ref2
outcome = obj.questData.qpOutcomeF(qpStimParams);

if outcome==1 % wrong choice
    intervalChoice = mod(testInterval,2)+1;
else
    intervalChoice = testInterval;
end

% The response is simulated, so make the responseTimeSecs nan
responseTimeSecs = nan;

end