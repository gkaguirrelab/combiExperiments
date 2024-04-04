dataPath = fullfile(filesep,'Users','aguirre','Downloads');
dirName = '65da51a06da124f01b739bf4';
subID = '001';
sesID = '20231114';
icaRejectSet = {[6],[7,9],[3],[0],[12,17]};
createMaskFlag = true;
%tedanaPreProcess(dataPath,dirName,subID,sesID,icaRejectSet,createMaskFlag);

fwSessID = '';
runIdxSet = [1 2 3 4 5];
tr = 2.040;
smoothSD = 0.1;
vxs = [];
results = fitTrigemModel(fwSessID,dirName,subID,sesID,runIdxSet,tr,vxs,smoothSD);
