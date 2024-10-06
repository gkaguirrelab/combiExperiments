
% General properties
fwSessID = '66fab2ad2ea3d370f9dc6608';
dataPath = fullfile(filesep,'Users','aguirre','Downloads');
subID = '001';
sesID = '20240930';
acqSet = {...
    '_task-trigem_acq-multiecho_run-01',...
    '_task-trigem_acq-multiecho_run-02',...
    '_task-trigem_acq-multiecho_run-03',...
    '_task-trigem_acq-multiecho_run-04',...
    '_task-trigem_acq-multiecho_run-05'...
    };
tr = 2.87;
echoTimesMs = [19.4,51.06,82.72];
nNoiseEPIs = 2;

% Set up the python environment variables
setupEnv

% nordic (before fmriprep)
dirName = 'dset';
applyNordic(dataPath,dirName,subID,sesID,acqSet,nNoiseEPIs,length(echoTimesMs));

% createMasks (after fmriprep)
dirName = 'fprep';
createMasks(dataPath,dirName,subID,sesID,acqSet);

% tedana (after fmriprep)
dirName = 'fprep';
icaRejectSet = {...
    [15,16,18,38],...
    [3,5,7,14,49,50],...
    [1,20],...
    [1,4,8,22,23],...
    [9,22,60,61]...
    };
tedanaPreProcess(dataPath,dirName,subID,sesID,acqSet,echoTimesMs,icaRejectSet);

% forward model
dirName = 'fprep';
stimSeq = [0,0,8,8,6,7,5,2,5,3,3,9,6,6,9,5,10,7,1,0,2,3,4,3,6,8,7,10,9,3,2,9,8,2,6,4,5,1,2,7,3,7,4,6,1,7,2,10,5,8,10,0,7,9,1,6,2,4,1,4,7,6,3,1,1,10,10,2,8,0,9,4,4,2,0,3,0,6,5,4,10,6,10,4,9,9,2,2,1,5,9,10,1,8,1,3,5,6,0,4,8,9,0,1,9,7,8,3,10,8,4,0,5,5,7,7,0,10,3,8,5,0,0];
stimLabelSet = {'0psi','1.0psi','1.5psi','2.1psi','3.1psi','4.5psi','6.6psi','9.7psi','14.1psi','20.6psi','30psi'};
maskLabelSet = {'brainstem','GM'};
smoothSD = 1.0;
averageVoxels = false;
useTedanaResults = true;
resultLabel = sprtinf('forwardModel_smooth=%2.1f',smoothSD);

results = fitTrigemModel(fwSessID,dataPath,dirName,subID,sesID,acqSet,...
    tr,nNoiseEPIs,maskLabelSet,stimSeq,stimLabelSet,...
    smoothSD,averageVoxels,useTedanaResults,resultLabel);
