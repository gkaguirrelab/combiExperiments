% Run through the set of reference PSI pressures

subjectID = 'HERO_gka';
stimPressureSetPSI = [2.13, 3.11, 4.53, 6.62, 9.65, 14.09, 20.56];
nLevels = length(stimPressureSetPSI);

[~,stimOrderIdx] = sort(rand(1,nLevels));

% for ii = 1:nLevels
%     thisStim = stimPressureSetPSI(stimOrderIdx(ii));
% 
%     % Run two blocks using a staircase
%     runDiscrimPuffThresh(subjectID,thisStim,'nBlocks',2,'useStairCase',true);
% 
% end

for ii = 1:nLevels
    thisStim = stimPressureSetPSI(stimOrderIdx(ii));

    % Switch to Quest+ for another 5 blocks
    runDiscrimPuffThresh(subjectID,thisStim,'nBlocks',5,'useStairCase',false);

end
