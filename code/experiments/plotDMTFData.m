
% Housekeeping
%close all
clear

% Get the subject ID
subjectID = GetWithDefault('Subject ID','FLIC_xxxx');

% The light levels and directions
NDlabelsAll = {'0x5','3x5'};
modDirections = {'LminusM_wide','LightFlux'};
targetPhotoreceptorContrast = [0.075,0.333];
plotColor = {'r','k'};

% Define where the experimental files are saved
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');
projectName = 'combiLED';
dropBoxSubDir = 'FLIC_data';
subjectDir = fullfile(...
    dropBoxBaseDir,...
    dropBoxSubDir,...,
    projectName,...
    subjectID);
experimentName = 'DMTF';

figHandle = figure();
figuresize(600,600,'pt');
tiledlayout(length(NDlabelsAll),length(modDirections),"TileSpacing","tight","Padding","tight");

for nn = 1:length(NDlabelsAll)
    for dd = 1:length(modDirections)

        % Load the psych object for this direction and light level
        dataDir = fullfile(subjectDir,[modDirections{dd} '_ND' NDlabelsAll{nn}],experimentName);
        psychFileStem = [subjectID '_' modDirections{dd} '_' experimentName ...
            '_' strrep(num2str(targetPhotoreceptorContrast(dd)),'.','x')];
        filename = fullfile(dataDir,[psychFileStem '.mat']);
        if ~isfile(filename)
            continue
        else
            load(filename,'psychObj');
        end

        % Extract the ref and test frequencies
        refFreq = [psychObj.trialData.refFreq];
        testFreq = [psychObj.trialData.testFreq];

        % obtain a linear bias and variance across frequency
        [~,edges] = histcounts(log10(refFreq),10);
        Y = discretize(log10(refFreq),edges);
        nBins = length(edges)-1;

        for bb = 1:nBins
            logVariance(bb) = std(log10(testFreq(Y==bb))).^2;
            linearBias(bb) = mean(testFreq(Y==bb)-refFreq(Y==bb));
            binLabels{bb} = sprintf('%2.1f - %2.1f',round(10^edges(bb),1),round(10.^edges(bb+1),1));
        end

        % Get the goodjobVec and boundary
        goodJobCriterionDb = psychObj.goodJobCriterionDb;
        goodJobVec = [psychObj.trialData.goodJob];
        proportionGoodjob = sum(goodJobVec)/length(goodJobVec);
        fprintf(['Proportion good job ' modDirections{dd} ' ND' NDlabelsAll{nn} ': %2.2f\n'],proportionGoodjob)

        % Plot the unit slope and good job feedback boundaries
        nexttile();
        semilogx([0.5 60],[0 0],'--k','LineWidth',1.5)        
        hold on
        xFitLog = linspace(0,2,100)';
        xFit = 10.^(xFitLog);
        semilogx(xFit,xFit.*db2pow(goodJobCriterionDb)-xFit,':k','LineWidth',1.5)        
        semilogx(xFit,xFit./db2pow(goodJobCriterionDb)-xFit,':k','LineWidth',1.5)        
                
        scatter(refFreq(goodJobVec),testFreq(goodJobVec)-refFreq(goodJobVec),'k','filled','o','MarkerEdgeColor','none','MarkerFaceAlpha',0.25);
        scatter(refFreq(~goodJobVec),testFreq(~goodJobVec)-refFreq(~goodJobVec),'r','filled','o','MarkerEdgeColor','none','MarkerFaceAlpha',0.25);
        xlim([0.5 60])
        ylim([-30 30])
        axis square
        a=gca();
        a.XTick = [1,2,4,8,16,32];
%        a.YTick = [1,2,4,8,16,32];
        xlabel('Reference Frequency [Hz]')
        ylabel('Error [Hz]')
        box off
        title([modDirections{dd} ' ND' NDlabelsAll{nn}],'Interpreter','none');

        % Add a fit line.
        mdl = fitlm(log10(refFreq),log10(testFreq));
        yFitLog = predict(mdl,xFitLog);
        yFit = 10.^(yFitLog);
        plot(xFit,yFit-xFit,'-b','LineWidth',2);

        % Add a shaded region to indicate the variance of the residuals
        meanStd = std(mdl.Residuals.Raw);
        xVerts = [1 32 32 1];
        yVertsLog = predict(mdl,log10(xVerts'))';
        yVerts = 10.^(yVertsLog + repmat(meanStd,1,4) .* [0.5 0.5 -0.5 -0.5]);
%        patch(xVerts,yVerts-xVerts,'b','FaceColor','b','LineStyle','none','FaceAlpha',.3)

    end
end