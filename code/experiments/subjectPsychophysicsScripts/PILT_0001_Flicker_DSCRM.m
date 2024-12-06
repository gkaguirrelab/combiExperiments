% Run through the set of reference flicker frequencies

subjectID = 'PILT_0001';
flickerFreqSetHz = [30,15,7.5,3.75,1.875];
nLevels = length(flickerFreqSetHz);

[~,stimOrderIdx] = sort(rand(1,nLevels));

for ii = 1:nLevels
    thisStim = stimPressureSetPSI(stimOrderIdx(ii));

    % Run two blocks using a staircase
    runDiscrimFlickerThresh(subjectID,thisStim,'nBlocks',2,'useStairCase',true);

end

for ii = 1:nLevels
    thisStim = flickerFreqSetHz(stimOrderIdx(ii));

    % Switch to Quest+ for another 5 blocks
    runDiscrimFlickerThresh(subjectID,thisStim,'nBlocks',5,'useStairCase',false);

end
