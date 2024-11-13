
% General properties
dataPath = fullfile(filesep,'Users','aguirre','Downloads');
rawDataPath = fullfile(dataPath,'flywheel','gkaguirrelab','trigeminal');
subID = '001';
sesID = '20241014';
acqSet = {...
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
echoTimesMs = [19.4,51.06,82.72];
nNoiseEPIs = 2;

% Set up the python environment variables
setupEnv

% nordic (before fmriprep)
%{
    dirName = 'dset';
    applyNordic(dataPath,dirName,subID,sesID,acqSet,nNoiseEPIs,length(echoTimesMs));
%}

% createMasks (after fmriprep)
dirName = 'dset/fprep';
createMasks(dataPath,dirName,subID,sesID,acqSet);

% tedana (after fmriprep)
dirName = 'dset/fprep';
icaRejectSet = {};
applyTedana(dataPath,dirName,subID,sesID,acqSet,echoTimesMs,icaRejectSet);

% forward model
dirName = 'dset/fprep';
stimSeq = [0,0,8,8,6,7,5,2,5,3,3,9,6,6,9,5,10,7,1,0,2,3,4,3,6,8,7,10,9,3,2,9,8,2,6,4,5,1,2,7,3,7,4,6,1,7,2,10,5,8,10,0,7,9,1,6,2,4,1,4,7,6,3,1,1,10,10,2,8,0,9,4,4,2,0,3,0,6,5,4,10,6,10,4,9,9,2,2,1,5,9,10,1,8,1,3,5,6,0,4,8,9,0,1,9,7,8,3,10,8,4,0,5,5,7,7,0,10,3,8,5,0,0];
stimLabelSet = {'0psi','1.0psi','1.5psi','2.1psi','3.1psi','4.5psi','6.6psi','9.7psi','14.1psi','20.6psi','30psi'};

maskLabelSet = {'brainstem','GM','WM'};
smoothSD = 0.25;
averageVoxels = false;
useTedanaResults = true;
resultLabel = sprintf(['forwardModel_' sesID '_plusNewAndNuis_smooth=%2.1f'],smoothSD);

results = fitTrigemModel(rawDataPath,dataPath,dirName,subID,sesID,acqSet,...
    tr,nNoiseEPIs,maskLabelSet,stimSeq,stimLabelSet,...
    smoothSD,averageVoxels,useTedanaResults,resultLabel);
