function plotROIs(dataPath,dirName,subID,sesID,resultsDir)
% Plot some results of the analysis
%
%{
    dataPath = fullfile(filesep,'Users','aguirre','Downloads');
    dirName = 'dset/fprep';
    subID = '001';
    sesID = [repmat({'20240930'},1,5),repmat({'20241014'},1,9)];
    resultsDir = '/Users/aguirre/Downloads/dset/fprep/forwardModel_2sess_smooth=0.5';
    plotROIs(dataPath,dirName,subID,sesID,resultsDir);
%}

% Load the results file
fileName = fullfile(resultsDir,[subID '_trigemResults.mat']);
load(fileName,'results');

% Load the template image
fileName = fullfile(resultsDir,[subID '_epiTemplate.nii']);
templateImage = MRIread(fileName);

% Get the dimensions of the template image
xyz = templateImage.volsize;

% Create a map of the R2 of the model fit
volVec = results.R2;
volVec(isnan(volVec)) = 0;
r2Map = reshape(volVec,xyz(1),xyz(2),xyz(3));

% Load the brainstem and GM masks
repoMaskDir = fullfile(dataPath,dirName,['sub-',subID],['ses-',sesID{1}],'mask');
nameStem = ['sub-',subID,'_ses-',sesID{1}];
gmMaskFile = fullfile(repoMaskDir,[nameStem '_space-MNI152NLin2009cAsym_label-GM.nii.gz']);
wmMaskFile = fullfile(repoMaskDir,[nameStem '_space-MNI152NLin2009cAsym_label-WM.nii.gz']);
bsMaskFile = fullfile(repoMaskDir,[nameStem '_space-MNI152NLin2009cAsym_label-brainstem.nii.gz']);

gmMask = MRIread(gmMaskFile);
gmMask = gmMask.vol;
wmMask = MRIread(wmMaskFile);
wmMask = wmMask.vol;
bsMask = MRIread(bsMaskFile);
bsMask = bsMask.vol;
mask = gmMask+wmMask;

% Create a map of log-linear increase with stimulation
idx = find(results.R2>0.1);
X = (1:10)';
rho = zeros(size(results.R2));
for ii = 1:length(idx)
    betas = results.params(idx(ii),1:154);
    betas = reshape(betas,11,14);
    betas = betas - betas(:,1);
    bm = mean(betas(2:11,:),2);
    rho(idx(ii)) = corr(X,bm);
end
rhoMap = reshape(rho,xyz(1),xyz(2),xyz(3));
newImage = templateImage;
newImage.vol = rhoMap;
fileName = fullfile(resultsDir,[subID '_trigem_logLinearRho.nii']);
MRIwrite(newImage, fileName);

% Save a "cleaned" map of the R2 effect
clustThresh = 25;
r2MapClean = r2Map;
r2MapClean(rhoMap<=0) = 0;
S = regionprops3(r2MapClean,'Volume','VoxelIdxList','VoxelList');
for ii = 1:size(S,1)
    if S(ii,"Volume") < clustThresh
        r2MapClean(S(ii,'VoxelIdxList'))=0;
    end
end
newImage = templateImage;
newImage.vol = r2MapClean;
fileName = fullfile(resultsDir,[subID '_cleanedR2Map.nii']);
MRIwrite(newImage, fileName);


% Plot the response in some big cortical regions
statThresh = 0.35;
subRhoMap = zeros(size(rhoMap));
subRhoMap(gmMask>0.5) = rhoMap(gmMask>0.5);
S = regionprops3(subRhoMap>statThresh,subRhoMap,'Volume','VoxelIdxList','VoxelList','MeanIntensity');
[~,sortIdx] = sort(abs(S.Volume),'descend');
S = S(sortIdx,:);

% Loop through the 2 biggest regions
roiLabels = {'R_S1','L_S1'};
figure
tiledlayout(3,1);
for ii = 1:2

    % Save a map of this region
    roiMap=zeros(size(r2Map));
    voxIdx = S.VoxelIdxList{ii};
    roiMap(voxIdx)=1;
    newImage = templateImage;
    newImage.vol = roiMap;
    fileName = fullfile(resultsDir,sprintf([subID '_' roiLabels{ii} '_trigem_rho_thresh_%2.3f_ROI_%d.nii'],statThresh,ii));
    MRIwrite(newImage, fileName);

    % Save a plot of the beta values
    nexttile;
    betas = mean(results.params(voxIdx,1:154));
    betas = reshape(betas,11,14);
    betas = betas - betas(1,:);
    bm = mean(betas,2);
    bm = bm(2:end)';
    bs = std(betas,[],2)/sqrt(14);
    bs = bs(2:end)';
    patch([1:10,10:-1:1],[bm-bs, fliplr(bm+bs)],'r','FaceAlpha',0.2,'EdgeColor','none');
    hold on
    plot(1:10,bm,'.-k');
    title(sprintf([roiLabels{ii} ' %d , rho = %2.2f, vol = %d'],ii,S.MeanIntensity(ii),S.Volume(ii)))
    ylim([-2 6]);
    xlim([0 11]);
    ylabel('BOLD %');
    xlabel('stimulus [PSI]');
    a = gca();
    a.XTick = [1 5 10];
    a.XTickLabel = {'1','4.5','30'};

end



% Plot the negative cortical response
%{
statThresh = 0.35;
subRhoMap = zeros(size(rhoMap));
subRhoMap(gmMask>0.5) = rhoMap(gmMask>0.5);
S = regionprops3(subRhoMap<(-statThresh),subRhoMap,'Volume','VoxelIdxList','VoxelList','MeanIntensity');
[~,sortIdx] = sort(abs(S.Volume),'descend');
S = S(sortIdx,:);

% Loop through the 1 biggest region
roiLabels = {'occipital'};
for ii = 1:1

    % Save a map of this region
    roiMap=zeros(size(r2Map));
    voxIdx = S.VoxelIdxList{ii};
    roiMap(voxIdx)=1;
    newImage = templateImage;
    newImage.vol = roiMap;
    fileName = fullfile(resultsDir,sprintf([subID '_' roiLabels{ii} '_trigem_rho_thresh_%2.3f_ROI_%d.nii'],statThresh,ii));
    MRIwrite(newImage, fileName);

    % Save a plot of the beta values
    nexttile;
    betas = mean(results.params(voxIdx,1:154));
    betas = reshape(betas,11,14);
    betas = betas - betas(1,:);
    bm = mean(betas,2);
    bm = bm(2:end)';
    bs = std(betas,[],2)/sqrt(14);
    bs = bs(2:end)';
    patch([1:10,10:-1:1],[bm-bs, fliplr(bm+bs)],'b','FaceAlpha',0.2,'EdgeColor','none');
    hold on
    plot(1:10,bm,'.-k');
    title(sprintf([roiLabels{ii} ' %d , rho = %2.2f, vol = %d'],ii,S.MeanIntensity(ii),S.Volume(ii)))
    ylim([-2 6]);
    xlim([0 11]);
    ylabel('BOLD %');
    xlabel('stimulus [PSI]');
    a = gca();
    a.XTick = [1 5 10];
    a.XTickLabel = {'1','4.5','30'};

end
%}

% Plot the response the subcortex
statThresh = 0.25;
subRhoMap = zeros(size(rhoMap));
subRhoMap(bsMask>0.5) = rhoMap(bsMask>0.5);
S = regionprops3(subRhoMap>statThresh,subRhoMap,'Volume','VoxelIdxList','VoxelList','MeanIntensity');
[~,sortIdx] = sort(abs(S.Volume),'descend');
S = S(sortIdx,:);

% Loop through the 2 biggest regions
roiLabels = {'caudate','thalamus'};
for ii = 2:2

    % Save a map of this region
    roiMap=zeros(size(r2Map));
    voxIdx = S.VoxelIdxList{ii};
    roiMap(voxIdx)=1;
    newImage = templateImage;
    newImage.vol = roiMap;
    fileName = fullfile(resultsDir,sprintf([subID '_trigem_rho_thresh_%2.3f_ROI_%d.nii'],statThresh,ii));
    MRIwrite(newImage, fileName);

    % Save a plot of the beta values
    nexttile;
    betas = mean(results.params(voxIdx,1:154));
    betas = reshape(betas,11,14);
    betas = betas - betas(1,:);
    bm = mean(betas,2);
    bm = bm(2:end)';
    bs = std(betas,[],2)/sqrt(14);
    bs = bs(2:end)';
    patch([1:10,10:-1:1],[bm-bs, fliplr(bm+bs)],'r','FaceAlpha',0.2,'EdgeColor','none');
    hold on
    plot(1:10,bm,'.-k');
    title(sprintf([roiLabels{ii} ' %d , rho = %2.2f, vol = %d'],ii,S.MeanIntensity(ii),S.Volume(ii)))
    ylim([-2 6]);
    xlim([0 11]);
    ylabel('BOLD %');
    xlabel('stimulus [PSI]');
    a = gca();
    a.XTick = [1 5 10];
    a.XTickLabel = {'1','4.5','30'};

end

end
%     rawVoxIdx = [];
%     for bb = 1:length(thisIdxSet)
%         sIdx = find(cellfun(@(x) any(x==thisIdxSet(bb)),[S.VoxelIdxList]));
%         rawVoxIdx{bb} = S.VoxelIdxList{sIdx};
%     end
%     voxIdx{ii} = cell2mat(rawVoxIdx');
%     betas = mean(results.params(voxIdx{ii},1:35));
%     betas = reshape(betas,7,5)';
%     betas = betas(:,1:5);
%     betas = betas - betas(:,1);
%     betas = betas(:,2:5);
%     bm = mean(betas);
%     bs = std(betas)/sqrt(5);
%     patch([1:4,4:-1:1],[bm-bs, fliplr(bm+bs)],plotColor{ii},'FaceAlpha',0.2,'EdgeColor','none');
%     hold on
%     plot(1:4,bm,['o-' plotColor{ii}]);
%     hold on
%
%     % Save a map of this region
%     roiMap=zeros(size(r2Map));
%     roiMap(voxIdx{ii})=1;
%     newImage = templateImage;
%     newImage.vol = roiMap;
%     fileName = fullfile(saveDir,sprintf([subID '_trigem_R2_thresh_%2.3f_%d_ROI_%d.nii'],r2Thresh(ii),clusterThresh(ii),ii));
%     MRIwrite(newImage, fileName);
%
% end
% a=gca();
% a.XTick = 1:4;
% a.XTickLabel = {'3.2','7.5','15','30'};
% xlim([0.25,5.25]);
% xlabel('Stimulus Pressure [PSI]')
% ylabel('BOLD repsonse [%∆]')
% fileName = fullfile(saveDir,sprintf([subID '_trigem_R2_thresh_%2.3f_%d_betaPlots.pdf'],r2Thresh(ii),clusterThresh(ii)));
% saveas(a,fileName);
%
% % Plot the time-series data and fit for a selected region
% roiToPlot = 2;
% resultsROI = forwardModel(data,stimulus,tr,...
%     'stimTime',stimTime,...
%     'vxs',voxIdx{roiToPlot},...
%     'averageVoxels',true,...
%     'verbose',false,...
%     'modelClass',modelClass,...
%     'modelOpts',modelOpts,...
%     'verbose',true);
% figFields = fieldnames(resultsROI.figures);
% for ii = 1:length(figFields)
%     figHandle = struct2handle(resultsROI.figures.(figFields{ii}).hgS_070000,0,'convert');
%     figHandle.Visible = 'on';
%     fileName = fullfile(saveDir,sprintf([subID '_ROI_%d_modelFitFig_%d.pdf'],roiToPlot,ii));
%     saveas(figHandle,fileName);
% end