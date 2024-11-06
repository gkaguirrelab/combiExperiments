function intervalChoice = getSimulatedResponse(obj,qpStimParams,fasterInterval)

% Get the simulated choice of ref1 or ref2
outcome = obj.questData.qpOutcomeF(qpStimParams);

if outcome==1 % wrong choice
    intervalChoice = mod(fasterInterval,2)+1;
else
    intervalChoice = fasterInterval;
end

end