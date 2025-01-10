% Run through the set of reference flicker frequencies

subjectID = 'PILT_0004';
refFreqHz = [24,12,6,3,1.5];
NDlabel = '3x5';
simulateFlag = false;

% [~,stimOrderIdx] = sort(rand(1,nLevels));
% nLevels = 2*length(flickerFreqSetHz);
% for ii = 1:nLevels
%     refFreqHz = flickerFreqSetHz(stimOrderIdx(ii));
% 
%     % Run two blocks using a staircase, which will be one of each of the
%     % two mod directions (LightFlux and L–M).
%     runDiscrimFlickerThresh(subjectID,NDlabel,refFreqHz,'nBlocks',2,'useStaircase',true,...
%         'simulateResponse',simulateFlag,'simulateStimuli',simulateFlag);
% 
% end

% Use Quest+
runDiscrimFlickerThresh(subjectID,NDlabel,refFreqHz,'nBlocks',10,'useStaircase',false, ...
    'simulateResponse',simulateFlag,'simulateStimuli',simulateFlag);

