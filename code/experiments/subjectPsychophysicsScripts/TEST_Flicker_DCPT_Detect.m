% Using two CombiLEDs to produce flicker

subjectID = 'SM';
% Run through the set of flicker frequencies
testFreqSetHz = [ 3.0000    5.4216    9.7980   17.7069   32.0000];
%testFreqSetHz = [8];  
NDlabel = '1';
simulateFlag = false;
useKeyboardFlag = false;

% Use Quest+

runDCPT_detect(subjectID,NDlabel,testFreqSetHz,'nBlocks',10,'useStaircase',false, ...
    'simulateResponse',simulateFlag,'simulateStimuli',simulateFlag, 'randomCombi', true, ...
    'useKeyboardFlag',useKeyboardFlag);


