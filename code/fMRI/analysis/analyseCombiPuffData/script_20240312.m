    dataPath = fullfile(filesep,'Users','aguirre','Downloads');
    dirName = '65f1d142f84641b1153a9010';
    subID = '001';
    sesID = '20240312';
    icaRejectSet = {[],[13,14],[16],[5,12,15,18],[7]};
    createMaskFlag = false;
    tedanaPreProcess(dataPath,dirName,subID,sesID,icaRejectSet,createMaskFlag);
