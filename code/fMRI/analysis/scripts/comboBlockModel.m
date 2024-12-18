
% General properties
dataPath = fullfile(filesep,'Users','aguirre','Downloads');
rawDataPath = fullfile(dataPath,'flywheel','gkaguirrelab','trigeminal');
subID = '001';
sesID = [repmat({'20240930'},1,5),repmat({'20241014'},1,9)];
acqSet = {...
    '_task-trigem_acq-multiecho_run-01',...
    '_task-trigem_acq-multiecho_run-02',...
    '_task-trigem_acq-multiecho_run-03',...
    '_task-trigem_acq-multiecho_run-04',...
    '_task-trigem_acq-multiecho_run-05',...
    '_task-trigem_acq-multiecho_run-01',...
    '_task-trigem_acq-multiecho_run-02',...
    '_task-trigem_acq-multiecho_run-03',...
    '_task-trigem_acq-multiecho_run-04',...
    '_task-trigem_acq-multiecho_run-05',...
    '_task-trigem_acq-multiecho_run-06',...
    '_task-trigem_acq-multiecho_run-07',...
    '_task-trigem_acq-multiecho_run-08',...
    '_task-trigem_acq-multiecho_run-09'...
    };
tr = 2.866;
nNoiseEPIs = 2;

dirName = 'dset/fprep';
stimSeq = [0,0,1,1,1,1,1,0,1,0,0,1,1,1,1,1,1,1,0,0,0,0,0,0,1,1,1,1,1,0,0,1,1,0,1,0,1,0,0,1,0,1,0,1,0,1,0,1,1,1,1,0,1,1,0,1,0,0,0,0,1,1,0,0,0,1,1,0,1,0,1,0,0,0,0,0,0,1,1,0,1,1,1,0,1,1,0,0,0,1,1,1,0,1,0,0,1,1,0,0,1,1,0,0,1,1,1,0,1,1,0,0,1,1,1,1,0,1,0,1,1,0,0];
stimLabelSet = {'low','high'};

maskLabelSet = {'brainstem','GM','WM'};
smoothSD = 1.5;
averageVoxels = false;
averageAcquisitions = true;
useTedanaResults = true;
resultLabel = sprintf('forwardModel_2sessBlock_smooth=%2.1f',smoothSD);

results = fitTrigemModel(rawDataPath,dataPath,dirName,subID,sesID,acqSet,...
    tr,nNoiseEPIs,maskLabelSet,stimSeq,stimLabelSet,...
    smoothSD,averageVoxels,averageAcquisitions,useTedanaResults,resultLabel);
