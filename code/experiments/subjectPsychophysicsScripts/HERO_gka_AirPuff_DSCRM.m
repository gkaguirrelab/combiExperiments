% Run through the set of reference PSI pressures

subjectID = 'HERO_gka';
stimPressureSetPSI = [1.00, 1.46, 2.13, 3.11, 4.53, 6.62, 9.65, 14.09, 20.56, 30.00];
nLevels = length(stimPressureSetPSI);

[~,stimOrderIdx] = sort(rand(1,nLevels));

for ii = 1:nLevels
    thisStim = stimPressureSetPSI(stimOrderIdx(ii));
    runDiscrimPuffThresh(subjectID,thisStim)
end

