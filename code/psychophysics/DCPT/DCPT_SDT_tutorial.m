
% Tutorial for dichoptic discrimination task

% Have participants redo the practice if they get more than 50% (4)
% incorrect responses

subjectID = 'DEMO_discrim'; % DO NOT CHANGE
NDlabel = '0x5';


runDCPT_SDT(subjectID,NDlabel, ...
    'refFreqHz',10, 'targetPhotoContrast', 0.5, ...
    'nTrialsPerBlock',10,'nBlocks',1,...
    'collectEOGFlag',false,'demoModeFlag',true);
