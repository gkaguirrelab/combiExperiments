% Using two CombiLEDs to produce flicker

subjectID = 'SM';
% Run through the set of reference flicker frequencies
% refFreqHz = [24,12,6,3,1.5];
% refFreqHz = [ 3.0000    5.4216    9.7980   17.7069   32.0000];
refFreqHz = [17.7069];
NDlabelA = '0x6';
NDlabelB = '0x9';
simulateFlag = false;

% Use Quest+

runDCPTFlickerThresh(subjectID,NDlabelA,NDlabelB,refFreqHz,'nBlocks',1,'useStaircase',false, ...
    'simulateResponse',simulateFlag,'simulateStimuli',simulateFlag, 'randomCombi', true);


