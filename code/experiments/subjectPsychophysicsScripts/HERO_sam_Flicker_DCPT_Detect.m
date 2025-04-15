% Using two CombiLEDs to produce flicker

subjectID = 'HERO_sam';
% Run through the set of flicker frequencies
% testFreqSetHz = [ 3.0000    5.4216    9.7980   17.7069   32.0000];
testFreqSetHz = [3.0000    3.9025    5.0766    6.6039    8.5906   11.1750   14.5370   18.9103   24.5994   32.0000];
NDlabel = '0x5';
simulateFlag = false;
useKeyboardFlag = false;

% Use Quest+

runDCPT_detect(subjectID,NDlabel,testFreqSetHz,'nBlocks',10,'useStaircase',false, ...
    'simulateResponse',simulateFlag,'simulateStimuli',simulateFlag, 'randomCombi', true, ...
    'useKeyboardFlag',useKeyboardFlag);


