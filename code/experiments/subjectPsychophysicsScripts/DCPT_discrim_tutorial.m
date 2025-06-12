subjectID = 'DEMO_discrim';
refFreqHz = [3.0000, 20.0000];
NDlabel = '0x5';
stimParams = linspace(5, 6, 10);
nTrialsPerBlock = 8;
nBlocks = 2;
targetPhotoContrast = [0.10 0.10; 0.30 0.30];

runDCPT_discrim(subjectID,NDlabel,'stimParams', stimParams, ...
    'nTrialsPerBlock', nTrialsPerBlock, 'nBlocks', nBlocks, ...
    'targetPhotoContrast', targetPhotoContrast, 'refFreqHz', ...
    refFreqHz);