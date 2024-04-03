function results = fitTrigemModel(fwSessID,dirName,subID,sesID,runIdxSet,tr,vxs,averageVoxels)

%{
    fwSessID = '';
    dirName = '65da51a06da124f01b739bf4';
    subID = '001';
    sesID = '20231114';
    runIdxSet = [1 2 3 4 5];
    tr = 2.040;
    vxs = 978110;
    results = fitTrigemModel(fwSessIDs,dirNames,subIDs,sesIDs,runIdxSet,tr,vxs);
%}

if nargin < 8
    averageVoxels = false;
end

% The smoothing kernel for the fMRI data in space
smoothSD = 0.25;

% The polynomial degree used for high-pass filtering of the timeseries
polyDeg = 4;

% Set the typicalGain, which is about 0.1 as we have converted the data to
% proportion change
typicalGain = 0.1;

% Basic properties of the data
nAcqs = length(runIdxSet);

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
saveDir = fullfile(dataPath,dirName);

% Define the location of the maskVol
gmMaskFile = fullfile(saveDir,[subID '_space-T1_label-GM_2x2x2.nii.gz']);
wmMaskFile = fullfile(saveDir,[subID '_space-T1_label-WM_2x2x2.nii.gz']);

% Create the list of filenames and the vector of trs
dataFileNames = {}; covarFileNames = {};
for jj = 1:length(runIdxSet)
    nameStemFunc = ['sub-',subID,'_ses-',sesID,'_task-trigem_acq-me_run-'];
    dataFileNames{end+1} = fullfile(...
        dirName,...
        ['sub-',subID],['ses-',sesID],'tdna',...
        sprintf('run-%d',runIdxSet(jj)),sprintf([nameStemFunc '%d_space-T1_desc-optcomDenoised_bold.nii.gz'],runIdxSet(jj)));
    covarFileNames{end+1} = fullfile(...
        dataPath,...
        dirName,...
        ['sub-',subID],['ses-',sesID],'func',...
        sprintf([nameStemFunc '%d_desc-confounds_timeseries.tsv'],runIdxSet(jj)));
end

% Create the stimulus description
switch sesID
    case '20231114'
        [stimulus,stimTime,stimLabels] = makeStimMatrixPilot(nAcqs);
    otherwise
        [stimulus,stimTime,stimLabels] = makeStimMatrix(nAcqs);
end

% Obtain the nuisanceVars
nuisanceVars = assembleNuisanceVars(fwSessID,runIdxSet,tr,covarFileNames,covarSet);

% Load the data
[data,templateImage,maskVol] = parseDataFiles(dataPath,dataFileNames,smoothSD,gmMaskFile,wmMaskFile);
nTRs = size(data{1},2);

% Pick the voxels to analyze
if isempty(vxs)
    vxs = find(reshape(maskVol>0, [numel(maskVol), 1]));
    averageVoxels = false;
end

% Create the model opts, which includes stimLabels and typicalGain. The
% paraSD key-value controls how varied the HRF solutions can be. A value of
% 3 is fairly conservative and will keep the HRFs close to a canonical
% shape. This is necessary for the current experiment as the stimulus
% sequence does not uniquely constrain the temporal delay in the HRF.
modelOpts = {'stimLabels',stimLabels,'typicalGain',typicalGain,...
    'paraSD',5,'polyDeg',polyDeg,...
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

end