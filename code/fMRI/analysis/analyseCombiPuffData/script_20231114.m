dataPath = fullfile(filesep,'Users','aguirre','Downloads');
fwSessID = '';
dirName = '65da51a06da124f01b739bf4';
subID = '001';
sesID = '20231114';
icaRejectSet = {[6],[7,9],[3],[0],[12,17]};
createMaskFlag = true;
maskFile = '/Users/aguirre/Downloads/65da51a06da124f01b739bf4/sub-001/ses-20231114/fmap/sub-001_ses-20231114_acq-meSe_fmapid-mask.nii.gz';
%tedanaPreProcess(dataPath,dirName,subID,sesID,icaRejectSet,maskFile);

runIdxSet = [1 2 3 4 5];
tr = 2.040;
smoothSD = 0.1;
vxs = [];
results = fitTrigemModel(fwSessID,dirName,subID,sesID,runIdxSet,tr,vxs,smoothSD);
