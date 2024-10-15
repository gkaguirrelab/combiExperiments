function results = fitTrigemModel(rawDataPath,dataPath,dirName,subID,sesID,...
    acqSet,tr,nNoiseEPIs,maskLabelSet,stimSeq,stimLabelSet,smoothSD,...
    averageVoxels,averageAcquisitions,useTedanaResults,resultLabel)

%{
    rawDataPath = fullfile(filesep,'Users','aguirre','Downloads','flywheel','gkaguirrelab','trigeminal');
    dataPath = fullfile(filesep,'Users','aguirre','Downloads','dset');
    dirName = 'fprep';
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
    nNoiseEPIs = 2;
    maskLabelSet = {'brainstem','GM'};
    smoothSD = 1.0;
    averageVoxels = false;
    useTedanaResults = true;
    results = fitTrigemModel(rawDataPath,dataPath,dirName,subID,sesID,acqSet,tr,nNoiseEPIs,maskLabelSet,smoothSD,averageVoxels,useTedanaResults);
%}

% The number of initial TRs in each acquisition to set to zero to remove
% the effects of steady state tissue magnetization
nTRsToZero = 2;

% The polynomial degree used for high-pass filtering of the timeseries
polyDeg = 4;

% Set the typicalGain, which is about 1 as we have converted the data to
% percentage change
typicalGain = 1;

% There is some delay while the airpuff travels down the tube
fixedStimDelaySecs = 0;

% Basic properties of the data
nAcqs = length(acqSet);

% Handle the sesID variable
if ~iscell(sesID)
    sesID = repmat({sesID},1,nAcqs);
end

% This is the set of "confound" covariates returned by fmriprep that we
% will use to generate nuisance covaraites
covarSet = {'csf','csf_derivative1','framewise_displacement','trans_x',...
    'trans_x_derivative1','trans_y','trans_y_derivative1','trans_z',...
    'trans_z_derivative1','rot_x','rot_x_derivative1','rot_y',...
    'rot_y_derivative1','rot_z','rot_z_derivative1'};

% Define a place to save the results
saveDir = fullfile(dataPath,dirName,resultLabel);
mkdir(saveDir);

% Create the list of acquisition and covar filenames
dataFileNames = {}; covarFileNames = {};
for jj = 1:nAcqs
    % Define the nameStem for this subject / session
    nameStem = ['sub-',subID,'_ses-',sesID{jj}];
    % Define the repo directories
    repoFuncDir = fullfile(dataPath,dirName,['sub-',subID],['ses-',sesID{jj}],'func');
    % Get the path to the confounds tsv file
    covarFileNames{end+1} = fullfile(repoFuncDir,[nameStem acqSet{jj} '_part-mag_desc-confounds_timeseries.tsv' ]);
    % Identify the BOLD acquisitions
    if useTedanaResults
        dataFileNames{end+1} = fullfile(repoFuncDir,[nameStem acqSet{jj} '_space-MNI152NLin2009cAsym_desc-tdna_bold.nii.gz' ]);
    else
        dataFileNames{end+1} = fullfile(repoFuncDir,[nameStem acqSet{jj} '_part-mag_space-MNI152NLin2009cAsym_desc-preproc_bold.nii.gz' ]);
    end
end

% Load the mask file and derive the vxs. Use the mask from the first
% session
repoMaskDir = fullfile(dataPath,dirName,['sub-',subID],['ses-',sesID{1}],'mask');
nameStem = ['sub-',subID,'_ses-',sesID{1}];
maskFiles = cellfun(@(x) fullfile(repoMaskDir,[nameStem '_space-MNI152NLin2009cAsym_label-' x '.nii.gz']),maskLabelSet,'UniformOutput',false);

% Load the data
[data,templateImage,maskVol] = parseDataFiles(dataFileNames,smoothSD,nTRsToZero,maskFiles);
nTRs = size(data{1},2);

% Pick the voxels to analyze
vxs = find(reshape(maskVol>0, [numel(maskVol), 1]));

% Average across acquisitions if requested
if averageAcquisitions
    data = {mean(cat(3,data{:}),3)};
    nAcqs = 1;
end

% Create the stimulus description
extendedModelFlag = false;
[stimulus,stimTime,stimLabels] = makeStimMatrix(nAcqs,stimSeq,stimLabelSet,extendedModelFlag,fixedStimDelaySecs);

% Obtain the nuisanceVars
if averageAcquisitions
    nuisanceVars = {};
else
    nuisanceVars = assembleNuisanceVars(rawDataPath,subID,sesID,acqSet,tr,nNoiseEPIs,covarFileNames,covarSet);
end

% Create the model opts, which includes stimLabels and typicalGain. The
% paraSD key-value controls how varied the HRF solutions can be. A value of
% 3 is fairly conservative and will keep the HRFs close to a canonical
% shape. This is necessary for the current experiment as the stimulus
% sequence does not uniquely constrain the temporal delay in the HRF.
for ii = 1:nAcqs
    avgAcqIdx{ii} = (1:nTRs) + (ii-1)*nTRs;
end
modelOpts = {'stimLabels',stimLabels,'typicalGain',typicalGain,...
    'paraSD',3,'polyDeg',polyDeg,...
    'confoundStimLabel','',...
    'nuisanceVars',nuisanceVars,...
    'avgAcqIdx',avgAcqIdx};

% Define the modelClass
modelClass = 'mtSinai';

% Call the forwardModel
results = forwardModel(data,stimulus,tr,...
    'stimTime',stimTime,...
    'vxs',vxs,...
    'averageVoxels',averageVoxels,...
    'verbose',true,...
    'modelClass',modelClass,...
    'modelOpts',modelOpts,...
    'verbose',true);

% Save the results figures
figFields = fieldnames(results.figures);
if ~isempty(figFields)
    for ii = 1:length(figFields)
        fileName = fullfile(saveDir,sprintf([subID '_trigemResults_fig%d.pdf'],ii));
        saveas(results.figures.(figFields{ii}),fileName);
    end
end

% Save some files if we processed more than a single voxel
if numel(vxs)>1

    % Save the results
    fileName = fullfile(saveDir,[subID '_trigemResults.mat']);
    save(fileName,'results');

    % Save the template image
    fileName = fullfile(saveDir,[subID '_epiTemplate.nii']);
    MRIwrite(templateImage, fileName);

    % Save a map of R2 values
    xyz = templateImage.volsize;
    newImage = templateImage;
    volVec = results.R2;
    volVec(isnan(volVec)) = 0;
    r2Map = reshape(volVec,xyz(1),xyz(2),xyz(3));
    newImage.vol = r2Map;
    fileName = fullfile(saveDir,[subID '_trigem_R2.nii']);
    MRIwrite(newImage, fileName);

    % Save thresholded maps
    r2Thresh = [0.075,0.25,0.175];
    clusterThresh = [20,200,100];
    for tt = 1:length(r2Thresh)
        S=regionprops3(r2Map>r2Thresh(tt),'Volume','VoxelIdxList','VoxelList');
        goodClusters=[S.Volume] > clusterThresh(tt);
        S = S(goodClusters,:);
        r2MapThresh=zeros(size(r2Map));
        for i=1:size(S,1)
            idx=S.VoxelIdxList{i};
            r2MapThresh(idx)=r2Map(idx);
        end
        newImage.vol = r2MapThresh;
        fileName = fullfile(saveDir,sprintf([subID '_trigem_R2_thresh_%2.3f_%d.nii'],r2Thresh(tt),clusterThresh(tt)));
        MRIwrite(newImage, fileName);
    end

end

end
