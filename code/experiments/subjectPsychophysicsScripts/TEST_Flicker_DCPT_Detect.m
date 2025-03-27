% Using two CombiLEDs to produce flicker

subjectID = 'TESTRB';
% Run through the set of flicker frequencies
testFreqSetHz = [ 3.0000    5.4216    9.7980   17.7069   32.0000];
NDlabelC = '1';
NDlabelD = '1';
simulateFlag = false;

% Use Quest+

runDCPTFlickerDetectionThresh(subjectID,NDlabelC,NDlabelD,testFreqSetHz,'nBlocks',10,'useStaircase',false, ...
    'simulateResponse',simulateFlag,'simulateStimuli',simulateFlag, 'randomCombi', true);


