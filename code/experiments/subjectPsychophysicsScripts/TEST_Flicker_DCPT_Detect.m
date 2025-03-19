% Using two CombiLEDs to produce flicker

subjectID = 'TEST';
% Run through the set of reference flicker frequencies
% refFreqHz = [24,12,6,3,1.5];
% refFreqHz = [ 3.0000    5.4216    9.7980   17.7069   32.0000];
refFreqHz = [ 3.0000    5.4216    9.7980   17.7069   32.0000];
testFreqHz = [ 3.0000    5.4216    9.7980   17.7069   32.0000];
NDlabelC = '0';
NDlabelD = '0';
simulateFlag = false;

% Use Quest+

runDCPTFlickerDetectionThresh(subjectID,NDlabelC,NDlabelD,refFreqHz,testFreqHz,'nBlocks',1,'useStaircase',false, ...
    'simulateResponse',simulateFlag,'simulateStimuli',simulateFlag, 'randomCombi', true);


