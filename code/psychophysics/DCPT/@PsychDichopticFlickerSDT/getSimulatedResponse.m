function answerChoice = getSimulatedResponse(obj,qpStimParams)

% Get the simulated choice of the test or reference
outcome = obj.questData.qpOutcomeF(qpStimParams);

if outcome==1 % "No". Said they were the same.
    answerChoice = 1;
else 
    % "Yes". Said they were different
    answerChoice = 2;
end

end