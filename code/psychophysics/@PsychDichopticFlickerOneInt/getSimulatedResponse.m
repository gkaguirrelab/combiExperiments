function answerChoice = getSimulatedResponse(obj,qpStimParams)

% Get the simulated choice of the test or reference
outcome = obj.questData.qpOutcomeF(qpStimParams);

if outcome==1 % Incorrect. Said they were the same, but they are different
    answerChoice = 1;
else 
    % Made the correct choice - they are different
    answerChoice = 2;
end

end