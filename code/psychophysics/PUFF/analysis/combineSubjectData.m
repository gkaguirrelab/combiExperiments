close all
clear

subjects = {'BLNK_1001','BLNK_1003','BLNK_1006','BLNK_1007',...
    'BLNK_1009','BLNK_1010','BLNK_1011'};

for ss = 1:length(subjects)
    results{ss} = processModulateVideos(subjects{ss},'makePlotFlag',false);
end

