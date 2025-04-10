% Using two CombiLEDs to produce flicker

subjectID = 'HERO_rsb';
% Run through the set of flicker frequencies
% testFreqSetHz = [ 3.0000    5.4216    9.7980   17.7069   32.0000];
testFreqSetHz = [
    3.0000
    4.0750
    5.5340
    7.5141
    10.2000
    13.8362
    18.7685
    25.4748
    32.0000];
NDlabel = '0x5';
simulateFlag = false;
useKeyboardFlag = false;

% Use Quest+

runDCPT_detect(subjectID,NDlabel,testFreqSetHz,'nBlocks',10,'useStaircase',false, ...
    'simulateResponse',simulateFlag,'simulateStimuli',simulateFlag, 'randomCombi', true, ...
    'useKeyboardFlag',useKeyboardFlag);


