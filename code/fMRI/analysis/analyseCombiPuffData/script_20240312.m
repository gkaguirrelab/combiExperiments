dataPath = fullfile(filesep,'Users','aguirre','Downloads');
fwSessID = '65f083a829fdb99849fa2e95';
dirName = '65f1d142f84641b1153a9010';
subID = '001';
sesID = '20240312';
icaRejectSet = {[],[13,14],[16],[5,12,15,18],[7]};
createMaskFlag = false;
%tedanaPreProcess(dataPath,dirName,subID,sesID,icaRejectSet,createMaskFlag);

runIdxSet = [2 3 4 5];
tr = 2.040;
vxs = []; %978110;
results = fitTrigemModel(fwSessID,dirName,subID,sesID,runIdxSet,tr,vxs);
