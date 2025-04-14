% Using two CombiLEDs to produce flicker

subjectID = 'HERO_sam';
% Run through the set of flicker frequencies
% testFreqSetHz = [ 3.0000    5.4216    9.7980   17.7069   32.0000];
testFreqSetHz = [
    3.0000
    3.5940
    4.2650
    5.0870
    6.1040
    7.4170
    9.1110
    11.2810
    13.9480
    32.0000];
NDlabel = '0x5';
simulateFlag = false;
useKeyboardFlag = false;

% Use Quest+

runDCPT_detect(subjectID,NDlabel,testFreqSetHz,'nBlocks',10,'useStaircase',false, ...
    'simulateResponse',simulateFlag,'simulateStimuli',simulateFlag, 'randomCombi', true, ...
    'useKeyboardFlag',useKeyboardFlag);


