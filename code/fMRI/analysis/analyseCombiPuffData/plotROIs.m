
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