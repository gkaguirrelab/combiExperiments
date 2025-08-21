function intervalChoice = getSimulatedResponse(obj,qpStimParams,testInterval)

% Get the simulated choice of the test or reference
outcome = obj.questData.qpOutcomeF(qpStimParams);

if outcome==1 % selected ref
    intervalChoice = mod(testInterval,2)+1;
else 
    % Made the correct choice and selected the interval that contains the
    % test frequency
    intervalChoice = testInterval;
end

end