dataPath = fullfile(filesep,'Users','aguirre','Downloads');
dirName = '65da51a06da124f01b739bf4';
subID = '001';
sesID = '20231114';
icaRejectSet = {[2,3,4,6,9,13,14,19,20],[8,10,14],[9,10],[1,3,6,7,15],[1,9,15,17]};
createMaskFlag = true;
%tedanaPreProcess(dataPath,dirName,subID,sesID,icaRejectSet,createMaskFlag);

fwSessID = '';
runIdxSet = [1 2 3 4 5];
tr = 2.040;
vxs = []; %978110;
results = fitTrigemModel(fwSessID,dirName,subID,sesID,runIdxSet,tr,vxs);
