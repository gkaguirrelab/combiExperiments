
% Housekeeping
%close all
clear

% How many bins to use when calculating the variance across frequency? How
% much overlap to have between bins (expressed as a proportion)
nBins = 10;
binOverlap = 0.0;

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


% Set up a figure
figHandle = figure();
figuresize(600,600,'pt');
tiledlayout(length(NDlabelsAll),length(modDirections),"TileSpacing","tight","Padding","tight");

% Loop through the directions and light levels
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

        % Get the goodjobVec and boundary
        testRangedB = psychObj.testRangeDecibels;
        goodJobCriterionDb = psychObj.goodJobCriterionDb;
        goodJobVec = [psychObj.trialData.goodJob];
        proportionGoodjob = sum(goodJobVec)/length(goodJobVec);
        fprintf(['Proportion good job ' modDirections{dd} ' ND' NDlabelsAll{nn} ': %2.2f\n'],proportionGoodjob)

        % Plot the good job feedback and absolute boundaries
        nexttile();
        semilogx([0.5 60],[0 0],'--k','LineWidth',1.5)        
        hold on
        xFitLog = linspace(-1,2,100)';
        xFit = 10.^(xFitLog);
        semilogx(xFit,repmat(goodJobCriterionDb,size(xFit)),':k','LineWidth',1.5)        
        semilogx(xFit,-repmat(goodJobCriterionDb,size(xFit)),':k','LineWidth',1.5)        
        semilogx(xFit,repmat(testRangedB/2,size(xFit)),'-','Color',[0.5 0.5 0.5],'LineWidth',0.5)        
        semilogx(xFit,-repmat(testRangedB/2,size(xFit)),'-','Color',[0.5 0.5 0.5],'LineWidth',0.5)        
                
        scatter(refFreq(goodJobVec),pow2db(testFreq(goodJobVec)./refFreq(goodJobVec)),'k','filled','o','MarkerEdgeColor','none','MarkerFaceAlpha',0.25);
        scatter(refFreq(~goodJobVec),pow2db(testFreq(~goodJobVec)./refFreq(~goodJobVec)),'r','filled','o','MarkerEdgeColor','none','MarkerFaceAlpha',0.25);
        xlim([0.5 60])
        ylim([-6 6])
        axis square
        a=gca();
        a.XTick = [1,2,4,8,16,32];
        a.YTick = [-6 -4 -2 0 2 4 6];
        xlabel('Reference Frequency [Hz]')
        ylabel('Error [dB]')
        box off

        % Add a fit line.
        xData = log10(refFreq);
        yData = pow2db(testFreq./refFreq);
        mdl = fitlm(xData,yData,'RobustOpts','on');
        yFitDb = predict(mdl,xFitLog);
        plot(xFit,yFitDb,'-b','LineWidth',2);

        % Add the title
        title([subjectID ' ' modDirections{dd} ' ND' NDlabelsAll{nn} sprintf(' [%2.1f,%2.1f]',mdl.Coefficients.Estimate)],'Interpreter','none');

        % Add a plot line to indicate the variance of the residuals
        residuals = mdl.Residuals.Raw;
        [~,E]=discretize(log10(refFreq),nBins);
        binCenters = E(1:nBins)+(E(2)-E(1))/2;
        for rr = 1:nBins
            binStart = max([min(E),E(rr)-E(rr)*(binOverlap/2)]);
            binEnd = min([max(E),E(rr+1)+E(rr+1)*(binOverlap/2)]);
            idx = find(and(log(refFreq)>=binStart,log(refFreq)<=binEnd));
            stdVals(rr) = std(residuals(idx));
        end
        plot(10.^binCenters,stdVals,'o-m','LineWidth',2);

    end
end