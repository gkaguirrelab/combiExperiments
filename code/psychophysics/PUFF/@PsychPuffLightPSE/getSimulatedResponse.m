function intervalChoice = getSimulatedResponse(obj,qpStimParams)

% Get the simulated choice of selecting the first or second interval. The
% stimParam is the dB difference between the first and second interval
intervalChoice = obj.questData.qpOutcomeF(qpStimParams);

end