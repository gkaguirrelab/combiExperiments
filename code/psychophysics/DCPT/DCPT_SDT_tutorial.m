
% Tutorial for dichoptic discrimination task

% Have participants redo the the high and low frequency practice until they
% achieve 100% correct on a 10 block practice trial for each condition

subjectID = 'DEMO_discrim'; % DO NOT CHANGE
NDlabel = '0x5';


%% Low frequency
runDCPT_SDT(subjectID,NDlabel, ...
    'refFreqHz',4.1157, 'targetPhotoContrast', 0.5, ...
    'nTrialsPerBlock',10,'nBlocks',1,...
    'collectEOGFlag',false,'demoModeFlag',true);


%% High frequency
runDCPT_SDT(subjectID,NDlabel, ...
    'refFreqHz',14.5785, 'targetPhotoContrast', 0.5, ...
    'nTrialsPerBlock',10,'nBlocks',1,...
    'collectEOGFlag',false,'demoModeFlag',true);
