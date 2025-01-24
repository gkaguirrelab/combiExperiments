% Using two CombiLEDs to produce flicker

subjectID = 'PILT_0003';
% Run through the set of reference flicker frequencies
refFreqHz = [24,12,6,3,1.5];
NDlabel = '0x5';
simulateFlag = false;

% Use Quest+
runDichopticFlickerThresh(subjectID,NDlabel,refFreqHz,'nBlocks',10,'useStaircase',false, ...
    'simulateResponse',simulateFlag,'simulateStimuli',simulateFlag, 'randomCombi', true);


