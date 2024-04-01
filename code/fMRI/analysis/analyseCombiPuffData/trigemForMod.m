
% Housekeeping
clear
close all

% Whole brain or one voxel?
fitOneVoxel = true;

% The smoothing kernel for the fMRI data in space
smoothSD = 0.25;

% The polynomial degree used for high-pass filtering of the timeseries
polyDeg = 4;

% Set the typicalGain, which is about 0.1 as we have converted the data to
% proportion change
typicalGain = 0.1;

% Basic properties of the data
fwSessIDs = {'6553f6199caa786dfb1b24b6'};
dirNames = {'65da51a06da124f01b739bf4'};
subIDs = {'001'};
sesIDs = {'20231114'};
runIdxSets = {[1 2 3 4 5]};
nAcqs = sum(cellfun(@(x) length(x),runIdxSets));
tr = 2.040;
nTRs = 177;

% This is the set of "confound" covariates returned by fmriprep that we 
% will use to generate nuisance covaraites
covarSet = {'global_signal','csf','csf_derivative1','white_matter',...
    'white_matter_derivative1','framewise_displacement','trans_x',...
    'trans_x_derivative1','trans_y','trans_y_derivative1','trans_z',...
    'trans_z_derivative1','rot_x','rot_x_derivative1','rot_y',...
    'rot_y_derivative1','rot_z','rot_z_derivative1'};

% Define the top-level data directory
dataPath = fullfile(filesep,'Users','aguirre','Downloads');

% Define a place to save the results
saveDir = dataPath;

% Define the location of the maskVol
gmMaskFile = fullfile(dataPath,[subIDs{1} '_space-T1_label-GM_2x2x2.nii.gz']);
wmMaskFile = fullfile(dataPath,[subIDs{1} '_space-T1_label-WM_2x2x2.nii.gz']);

% Create the list of filenames and the vector of trs
dataFileNames = {}; covarFileNames = {};
for ii=1:length(dirNames)
    runIdxSet = runIdxSets{ii};
    for jj = 1:length(runIdxSet)
        nameStemFunc = ['sub-',subIDs{ii},'_ses-',sesIDs{ii},'_task-trigem_acq-me_run-'];
        dataFileNames{end+1} = fullfile(...
            dirNames{ii},...
            ['sub-',subIDs{ii}],['ses-',sesIDs{ii}],'tdna',...
            sprintf('run-%d',runIdxSet(jj)),sprintf([nameStemFunc '%d_space-T1_desc-optcomDenoised_bold.nii.gz'],runIdxSet(jj)));
        covarFileNames{end+1} = fullfile(...
            dataPath,...
            dirNames{ii},...
            ['sub-',subIDs{ii}],['ses-',sesIDs{ii}],'func',...
            sprintf([nameStemFunc '%d_desc-confounds_timeseries.tsv'],runIdxSet(jj)));
    end
end

% Load the data
[data,templateImage,maskVol] = parseDataFiles(dataPath,dataFileNames,smoothSD,gmMaskFile,wmMaskFile);

% Create the stimulus description
[stimulus,stimTime,stimLabels] = makeStimMatrixPilot(nAcqs);

% Obtain the nuisanceVars
nuisanceVars = assembleNuisanceVars(fwSessIDs{1},runIdxSets{1},tr,covarFileNames,covarSet);

% Pick the voxels to analyze
xyz = templateImage.volsize;
if fitOneVoxel
    % A single voxel
    %    ijk = [16,69,45];
    %    vxs = sub2ind(size(maskVol),ijk(1),ijk(2),ijk(3));
    vxs = 978110;
    averageVoxels = false;
else
    % Create a mask of brain voxels
    vxs = find(reshape(maskVol>0, [numel(maskVol), 1]));
    averageVoxels = false;
end

% Create the model opts, which includes stimLabels and typicalGain. The
% paraSD key-value controls how varied the HRF solutions can be. A value of
% 3 is fairly conservative and will keep the HRFs close to a canonical
% shape. This is necessary for the current experiment as the stimulus
% sequence does not uniquely constrain the temporal delay in the HRF.
modelOpts = {'stimLabels',stimLabels,'typicalGain',typicalGain,...
    'paraSD',3,'polyDeg',polyDeg,...
    'nuisanceVars',nuisanceVars,...
    'avgAcqIdx',repmat({1:nTRs},1,nAcqs) };

% Define the modelClass
modelClass = 'mtSinaiShift';

% Call the forwardModel
results = forwardModel(data,stimulus,tr,...
    'stimTime',stimTime,...
    'vxs',vxs,...
    'averageVoxels',averageVoxels,...
    'verbose',true,...
    'modelClass',modelClass,...
    'modelOpts',modelOpts,...
    'verbose',true);

% Show the results figures
figFields = fieldnames(results.figures);
if ~isempty(figFields)
    for ii = 1:length(figFields)
        figHandle = struct2handle(results.figures.(figFields{ii}).hgS_070000,0,'convert');
        figHandle.Visible = 'on';
    end
end

% Save some files if we processed the whole brain
if ~fitOneVoxel

    % Save the results
    fileName = fullfile(saveDir,[subIDs{1} '_trigemResults.mat']);
    save(fileName,'results');

    % Save the template image
    fileName = fullfile(saveDir,[subIDs{1} '_epiTemplate.nii']);
    MRIwrite(templateImage, fileName);

    % Save a map of R2 values
    newImage = templateImage;
    volVec = results.R2;
    volVec(isnan(volVec)) = 0;
    r2Map = reshape(volVec,xyz(1),xyz(2),xyz(3));
    newImage.vol = r2Map;
    fileName = fullfile(saveDir,[subIDs{1} '_trigem_R2.nii']);
    MRIwrite(newImage, fileName);

end

% Define ROIs based upon the R2 map and seed points. The first seed point
% is in the right somatosensory cortex, and the second seed point is in the
% left posterior brainstem at the ponto-medullary junction. For each ROI,
% re-run the forward model using the ROI as the vxs, and save plots of the
% resulting params
% seedIdx = [325117,120232];
% roiLabels = {'rightS1Cortex','leftPontoMedullary'};
% lowThresh = [0.404135,0.1855];
% 
% for ss = 1:length(seedIdx)
%     threshMap = r2Map;
%     threshMap(threshMap<lowThresh(ss))=0;
%     threshMap(threshMap>=lowThresh(ss))=1;
%     [i,j,k] = ind2sub(size(r2Map),seedIdx(ss));
%     roi = RegGrow(threshMap,0.01,[i j k],'kernel',ones(3,3,3));
%     newImage = templateImage;
%     newImage.vol = roi;
%     fileName = fullfile(saveDir,[subIDs{1} '_roi-' roiLabels{ss} '.nii']);
%     MRIwrite(newImage, fileName);
%     roiVxs = find(reshape(roi, [numel(roi), 1]));
% 
%     roiResults{ss} = forwardModel(data,stimulus,tr,...
%         'stimTime',stimTime,...
%         'vxs',roiVxs,...
%         'averageVoxels',true,...
%         'verbose',true,...
%         'modelClass',modelClass,...
%         'modelOpts',modelOpts,...
%         'verbose',true);
%     figFields = fieldnames(roiResults{ss}.figures);
%     figHandle = struct2handle(roiResults{ss}.figures.(figFields{2}).hgS_070000,0,'convert');
%     figHandle.Visible = 'on';
%     betas = roiResults{ss}.params(roiVxs(1),1:35);
%     betas = reshape(betas,7,5);
%     bm = mean(betas(1:5,:),2);
%     bs = std(betas(1:5,:),[],2)/sqrt(5);
%     figure
%     patch([1:5,5:-1:1]',[bm-bs;flipud(bm+bs)],'r','FaceAlpha',0.2,'EdgeColor','none');
%     hold on
%     plot(1:5,bm,'o-k');
%     a=gca();
%     a.XTick = 1:5;
%     a.XTickLabel = {'0','3.2','7.5','15','30'};
%     xlim([0.25,5.25]);
%     xlabel('Stimulus Pressure [PSI]')
%     ylabel('BOLD repsonse [%∆]')
% end
