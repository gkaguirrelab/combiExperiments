
% General properties
fwSessID = '66f17c99d49fdd0e6e9268e1';
dataPath = fullfile(filesep,'Users','aguirre','Downloads');
subID = '001';
sesID = '20240923';
acqSet = {...
    '_task-trigemmed_acq-multiecho_run-01',...
    '_task-trigemhi_acq-multiecho_run-01'};
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
icaRejectSet = {[],[],[]};
tedanaPreProcess(dataPath,dirName,subID,sesID,acqSet,echoTimesMs,icaRejectSet);

% forward model
dirName = 'fprep';
stimSeq = [0,0,3,3,4,0,2,0,4,4,2,1,4,3,1,0,1,3,2,4,1,1,2,2,3,0,0,2,2,3,4,3,0,1,4,2,0,4,1,2,1,3,3,2,4,4,0,3,1,1,0,0,1,1,3,0,4,4,2,3,3,1,2,1,4,0,2,4,1,0,3,4,3,2,2,0,0,3,2,2,1,1,4,2,3,1,0,1,3,4,1,2,4,4,0,2,0,4,3,3,0,0];
stimLabelSet = {'0psi','1.4psi','3.5psi','9.0psi','23.3psi'};
maskLabelSet = {'brainstem','GM'};
smoothSD = 1.0;
averageVoxels = false;
useTedanaResults = true;
resultLabel = sprtinf('forwardModel_smooth=%2.1f',smoothSD);

results = fitTrigemModel(fwSessID,dataPath,dirName,subID,sesID,acqSet,...
    tr,nNoiseEPIs,maskLabelSet,stimSeq,stimLabelSet,...
    smoothSD,averageVoxels,useTedanaResults);
