    dataPath = fullfile(filesep,'Users','aguirre','Downloads');
    dirName = '65da51a06da124f01b739bf4';
    subID = '001';
    sesID = '20231114';
    icaRejectSet = {[2,3,4,6,9,13,14,19,20],[8,10,14],[9,10],[1,3,6,7,15],[1,9,15,17]};
    tedanaPreProcess(dataPath,dirName,subID,sesID,icaRejectSet);
