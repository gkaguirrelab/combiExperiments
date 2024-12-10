% Run through the set of reference flicker frequencies

subjectID = 'PILT_0001';
flickerFreqSetHz = [30,15,7.5,3.75,1.875];
nLevels = length(flickerFreqSetHz);
NDlabel = '0x5';

[~,stimOrderIdx] = sort(rand(1,nLevels));

for ii = 1:nLevels
    refFreqHz = flickerFreqSetHz(stimOrderIdx(ii));

    % Run two blocks using a staircase, which will be one of each of the
    % two mod directions (LightFlux and L–M).
    runDiscrimFlickerThresh(subjectID,NDlabel,refFreqHz,'nBlocks',2,'useStaircase',true,...
        'simulateResponse',true,'simulateStimuli',true);

end

for ii = 1:nLevels
    refFreqHz = flickerFreqSetHz(stimOrderIdx(ii));

    % Switch to Quest+ for another 6 blocks
    runDiscrimFlickerThresh(subjectID,NDlabel,refFreqHz,'nBlocks',6,'useStaircase',false, ...
        'simulateResponse',true,'simulateStimuli',true);

end
