
% Tutorial for dichoptic discrimination task

% Have participants redo the practice if they get more than 50% (4)
% incorrect responses

subjectID = 'DEMO_discrim'; % DO NOT CHANGE
refFreqHz = [3.0000    4.8206    7.7460   12.4467   20.0000];
NDlabel = '0x5';
stimParams = linspace(0, 6.75, 10);
nTrialsPerBlock = 20;
nBlocks = 10;
targetPhotoContrast = [0.025, 0.10; 0.075, 0.30];
EOGFlag = true; 

if strcmp(subjectID, 'DEMO_discrim')

    runDCPT_discrim(subjectID,NDlabel,EOGFlag,'stimParams', stimParams, ...
        'nTrialsPerBlock', nTrialsPerBlock, 'nBlocks', nBlocks, ...
        'targetPhotoContrast', targetPhotoContrast, 'refFreqHz', ...
        refFreqHz, 'useStaircase', true);
else
    msg = 'Invalid subjectID. You must use the DEMO_discrim subjectID or you may ruin future data';
    error(msg)
end