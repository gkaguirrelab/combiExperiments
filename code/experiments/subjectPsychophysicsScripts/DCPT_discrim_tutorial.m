
% Tutorial for dichoptic discrimination task

% Have participants redo the practice if they get more than 50% (4)
% incorrect responses

subjectID = 'DEMO_discrim';
refFreqHz = [3.0000, 20.0000];
NDlabel = '0x5';
stimParams = linspace(5, 6, 10);
nTrialsPerBlock = 8;
nBlocks = 2;
targetPhotoContrast = [0.075, 0.30; 0.075, 0.30];
EOGFlag = false; 

runDCPT_discrim(subjectID,NDlabel,EOGFlag,'stimParams', stimParams, ...
    'nTrialsPerBlock', nTrialsPerBlock, 'nBlocks', nBlocks, ...
    'targetPhotoContrast', targetPhotoContrast, 'refFreqHz', ...
    refFreqHz);