function results = fitTrigemModel(fwSessID,dirName,subID,sesID,runIdxSet,tr,vxs,smoothSD,averageVoxels)

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

if nargin < 9
    averageVoxels = false;
end

% The polynomial degree used for high-pass filtering of the timeseries
polyDeg = 4;

% Set the typicalGain, which is about 1 as we have converted the data to
% percentage change
typicalGain = 1;

% Basic properties of the data
nAcqs = length(runIdxSet);

% This is the set of "confound" covariates returned by fmriprep that we
% will use to generate nuisance covaraites
covarSet = {'csf','csf_derivative1','framewise_displacement','trans_x',...
    'trans_x_derivative1','trans_y','trans_y_derivative1','trans_z',...
    'trans_z_derivative1','rot_x','rot_x_derivative1','rot_y',...
    'rot_y_derivative1','rot_z','rot_z_derivative1'};

% Define the top-level data directory
dataPath = fullfile(filesep,'Users','aguirre','Downloads');

% Define a place to save the results
saveDir = fullfile(dataPath,dirName,sprintf('forwardModel_smooth=%2.2f',smoothSD));
mkdir(saveDir);

% Define the location of the maskVol
gmMaskFile = fullfile(dataPath,dirName,[subID '_space-T1_label-GM_2x2x2.nii.gz']);
wmMaskFile = fullfile(dataPath,dirName,[subID '_space-T1_label-WM_2x2x2.nii.gz']);

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
for ii = 1:nAcqs
    avgAcqIdx{ii} = (1:nTRs) + (ii-1)*nTRs;
end
modelOpts = {'stimLabels',stimLabels,'typicalGain',typicalGain,...
    'paraSD',5,'polyDeg',polyDeg,...
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

    % Find some regions and plot the response
    r2Thresh = [0.075,0.25,0.25,0.175];
    clusterThresh = [20,200,200,100];
    idxWithin = {[534969,681401],988858,948669,944074};
    plotColor = {'r','k','k','g'};
    figure
    voxIdx = [];
    for ii = 1:length(r2Thresh)
        thisIdxSet = idxWithin{ii};
        S = regionprops3(r2Map>r2Thresh(ii),'Volume','VoxelIdxList','VoxelList');
        rawVoxIdx = [];
        for bb = 1:length(thisIdxSet)
            sIdx = find(cellfun(@(x) any(x==thisIdxSet(bb)),[S.VoxelIdxList]));
            rawVoxIdx{bb} = S.VoxelIdxList{sIdx};
        end
        voxIdx{ii} = cell2mat(rawVoxIdx');
        betas = mean(results.params(voxIdx{ii},1:35));
        betas = reshape(betas,7,5)';
        betas = betas(:,1:5);
        betas = betas - betas(:,1);
        betas = betas(:,2:5);
        bm = mean(betas);
        bs = std(betas)/sqrt(5);
        patch([1:4,4:-1:1],[bm-bs, fliplr(bm+bs)],plotColor{ii},'FaceAlpha',0.2,'EdgeColor','none');
        hold on
        plot(1:4,bm,['o-' plotColor{ii}]);
        hold on

        % Save a map of this region
        roiMap=zeros(size(r2Map));
        roiMap(voxIdx{ii})=1;
        newImage = templateImage;
        newImage.vol = roiMap;
        fileName = fullfile(saveDir,sprintf([subID '_trigem_R2_thresh_%2.3f_%d_ROI_%d.nii'],r2Thresh(ii),clusterThresh(ii),ii));
        MRIwrite(newImage, fileName);

    end
    a=gca();
    a.XTick = 1:4;
    a.XTickLabel = {'3.2','7.5','15','30'};
    xlim([0.25,5.25]);
    xlabel('Stimulus Pressure [PSI]')
    ylabel('BOLD repsonse [%∆]')
    fileName = fullfile(saveDir,sprintf([subID '_trigem_R2_thresh_%2.3f_%d_betaPlots.pdf'],r2Thresh(ii),clusterThresh(ii)));
    saveas(a,fileName);

    % Plot the time-series data and fit for a selected region
    roiToPlot = 2;
    resultsROI = forwardModel(data,stimulus,tr,...
        'stimTime',stimTime,...
        'vxs',voxIdx{roiToPlot},...
        'averageVoxels',true,...
        'verbose',false,...
        'modelClass',modelClass,...
        'modelOpts',modelOpts,...
        'verbose',true);
    figFields = fieldnames(resultsROI.figures);
    for ii = 1:length(figFields)
        figHandle = struct2handle(resultsROI.figures.(figFields{ii}).hgS_070000,0,'convert');
        figHandle.Visible = 'on';
        fileName = fullfile(saveDir,sprintf([subID '_ROI_%d_modelFitFig_%d.pdf'],roiToPlot,ii));
        saveas(figHandle,fileName);        
    end

end

end
