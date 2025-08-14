
simulatePsiParams = [0.05,1,1];
nTrials = 50;
nullTrialRate = []; correctRate= []; paramSet=[];
for kk = 1:50
    clear obj
    obj = PsychDichopticFlickerSDT([], modResultArr, [], 5,...
        'simulateMode',true,'simulatePsiParams',simulatePsiParams);
    for i=1:nTrials; obj.presentTrial; end
    nullTrialRate(kk) = sum([obj.questData.trialData.stim]==0)/nTrials;
    correctRate(kk) = sum([obj.questData.trialData.correct])/nTrials;
    [~,paramSet(kk,:)] = obj.reportParams;
end

fprintf('\n******************************\n')
fprintf('After %d trials: \n',nTrials);
fprintf('null trial rate: %2.2f\n',mean(nullTrialRate))
fprintf('correct rate: %2.2f\n',mean(correctRate))
fprintf('verid param values: %2.2f, %2.2f, %2.2f\n',simulatePsiParams);
fprintf('mean param values: %2.2f, %2.2f, %2.2f\n',mean(paramSet,1));
fprintf('std param values: %2.2f, %2.2f, %2.2f\n',std(paramSet));
obj.plotOutcome;