function plotROIs(dataPath,dirName,subID,sesID,resultsDir)
% Plot some results of the analysis. This is highly shaped to isolate a set
% of regions that I wish to illustrate in an NIH R01 application.
% Intellectually, some of this is equivalent to hand-drawing regions of
% interest to pick parts of the data I wish to highlight.
%
% Good for highlighting provocative aspects of preliminary data, not good
% for hypothesis testing.
%
%{
    dataPath = fullfile(filesep,'Users','aguirre','Downloads');
    dirName = 'dset/fprep';
    subID = '001';
    sesID = [repmat({'20240930'},1,5),repmat({'20241014'},1,9)];
    resultsDir = '/Users/aguirre/Downloads/dset/fprep/forwardModel_2sess_smooth=1.0';
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

% Save a "cleaned" rho map. First filter out tiny 2D regions
clustThresh = [7,5,10];
statThresh = 0.25;
rhoMapClean = rhoMap;
rhoMapClean(rhoMap<=statThresh) = 0;
for dd = 1:3
    for ss = 1:size(rhoMapClean,dd)
        switch dd
            case 1
                thisSlice = squeeze(rhoMapClean(ss,:,:));
            case 2
                thisSlice = squeeze(rhoMapClean(:,ss,:));
            case 3
                thisSlice = squeeze(rhoMapClean(:,:,ss));
        end
        binThisSlice = thisSlice;
        binThisSlice(binThisSlice>0) = 1;
        binThisSlice(binThisSlice<0) = 0;
        binThisSlice = logical(binThisSlice);
        S = regionprops(binThisSlice,'Area','PixelIdxList');
        if ~isempty(S)
            for ii = 1:size(S,1)
                if S(ii).Area < clustThresh(dd)
                    thisSlice(S(ii).PixelIdxList)=0;
                end
            end
        end
        switch dd
            case 1
                rhoMapClean(ss,:,:) = thisSlice;
            case 2
                rhoMapClean(:,ss,:) = thisSlice;
            case 3
                rhoMapClean(:,:,ss) = thisSlice;
        end
    end
end

% Now filter in 3D
clustThresh = 100;
S = regionprops3(rhoMapClean,'Volume','VoxelIdxList','VoxelList');
for ii = 1:size(S,1)
    if S(ii,"Volume") < clustThresh
        rhoMapClean(S(ii,'VoxelIdxList'))=0;
    end
end
newImage = templateImage;
newImage.vol = rhoMapClean;
fileName = fullfile(resultsDir,[subID '_cleanedRhoMap.nii']);
MRIwrite(newImage, fileName);

% Plot the response in some big cortical regions
statThresh = 0.25;
subRhoMap = rhoMapClean;
subRhoMap(bsMask>0.5) = 0;
S = regionprops3(subRhoMap>statThresh,subRhoMap,'Volume','VoxelIdxList','VoxelList','MeanIntensity','Centroid');
[~,sortIdx] = sort(abs(S.Volume),'descend');
S = S(sortIdx,:);

% Loop through the 2 biggest regions
roiLabels = {...
    'R_cerebellum','R_insula','R_S1','R_frontal',...
    'L_insula','R_parietal','R_frontal','R_S2',...
    'L_caudate','R_frontal','R_caudate','L_caudate',...
    'R_opticRads','R_midFront','L_cerebellum','R_frontal',...
    'R_precun','R_frontalWM','?','?'};
figure
tiledlayout(2,2);
for ii = [2 5]

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
    plot([1 10],[0 0],':k');
    hold on
    patch([1:10,10:-1:1],[bm-bs, fliplr(bm+bs)],'r','FaceAlpha',0.2,'EdgeColor','none');
    plot(1:10,bm,'.-k');    
    title(sprintf([roiLabels{ii} ' %d , rho = %2.2f, vol = %d'],ii,S.MeanIntensity(ii),S.Volume(ii)))
    ylim([-2 6]);
    xlim([0 11]);
    ylabel('BOLD %');
    xlabel('stimulus [PSI]');
    a = gca();
    a.XTick = [1 4 7 10];
    a.XTickLabel = {'1','3','10','30'};

end


% Plot the response the subcortex
statThresh = 0.25;
subRhoMap = zeros(size(rhoMapClean));
subRhoMap(bsMask>0.5) = rhoMapClean(bsMask>0.5);
S = regionprops3(subRhoMap>statThresh,subRhoMap,'Volume','VoxelIdxList','VoxelList','MeanIntensity');
[~,sortIdx] = sort(abs(S.Volume),'descend');
S = S(sortIdx,:);

% Loop through the 2 biggest regions
roiLabels = {'B_antThalamus','L_midbrain','R_postThalamus','R_midbrain','L_whitematter','R_postPons'};
for ii = [3 6]

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
    plot([1 10],[0 0],':k');
    hold on
    patch([1:10,10:-1:1],[bm-bs, fliplr(bm+bs)],'r','FaceAlpha',0.2,'EdgeColor','none');
    plot(1:10,bm,'.-k');
    title(sprintf([roiLabels{ii} ' %d , rho = %2.2f, vol = %d'],ii,S.MeanIntensity(ii),S.Volume(ii)))
    ylim([-2 6]);
    xlim([0 11]);
    ylabel('BOLD %');
    xlabel('stimulus [PSI]');
    a = gca();
    a.XTick = [1 4 7 10];
    a.XTickLabel = {'1','3','10','30'};

end

end