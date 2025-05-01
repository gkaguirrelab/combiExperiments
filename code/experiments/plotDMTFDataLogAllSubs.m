
% Housekeeping
%close all
clear

% Subject IDs
subjectIDs = {'FLIC_0001','FLIC_0002','FLIC_0003','FLIC_0004','FLIC_0005'};

% How many bins to use when calculating the variance across frequency?
nBins = 10;
binOverlap = 0;

% The light levels and directions
NDlabelsAll = {'0x5','3x5'};
modDirections = {'LminusM_wide','LightFlux'};
modDirectionLabels = {'L–M','LF'};
targetPhotoreceptorContrast = [0.075,0.333];
plotColor = {'r','k'};

% Define where the experimental files are saved
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');
projectName = 'combiLED';
dropBoxSubDir = 'FLIC_data';
experimentName = 'DMTF';


% Set up a figure
figHandle = figure();
figuresize(600,600,'pt');
tiledlayout(length(NDlabelsAll),length(modDirections),"TileSpacing","tight","Padding","tight");

% Loop through the directions and light levels
for nn = 1:length(NDlabelsAll)
    for dd = 1:length(modDirections)

        refFreq = []; testFreq = []; testFreqInitial = []; goodJobVec = [];

        for ss = 1:length(subjectIDs)

            % Set this subject directory
            subjectDir = fullfile(...
                dropBoxBaseDir,...
                dropBoxSubDir,...,
                projectName,...
                subjectIDs{ss});

            % Load the psych object for this direction and light level
            dataDir = fullfile(subjectDir,[modDirections{dd} '_ND' NDlabelsAll{nn}],experimentName);
            psychFileStem = [subjectIDs{ss} '_' modDirections{dd} '_' experimentName ...
                '_' strrep(num2str(targetPhotoreceptorContrast(dd)),'.','x')];
            filename = fullfile(dataDir,[psychFileStem '.mat']);
            if ~isfile(filename)
                continue
            else
                load(filename,'psychObj');
            end

            % Add to the entire set
            refFreq = [refFreq, [psychObj.trialData.refFreq]];
            testFreq = [testFreq, [psychObj.trialData.testFreq]];
            testFreqInitial = [testFreqInitial, [psychObj.trialData.testFreqInitial]];

            % Get the goodjobVec and boundary
            testRangedB = psychObj.testRangeDecibels;
            goodJobCriterionDb = psychObj.goodJobCriterionDb;
            goodJobVec = [goodJobVec, [psychObj.trialData.goodJob]];
            proportionGoodjob = sum(goodJobVec)/length(goodJobVec);
%            fprintf(['Proportion good job ' modDirections{dd} ' ND' NDlabelsAll{nn} ': %2.2f\n'],proportionGoodjob)

        end

        goodJobVec = logical(goodJobVec);

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

        scatter(refFreq(goodJobVec),pow2db(testFreq(goodJobVec)./refFreq(goodJobVec)),15,'k','filled','o','MarkerEdgeColor','none','MarkerFaceAlpha',0.15);
        scatter(refFreq(~goodJobVec),pow2db(testFreq(~goodJobVec)./refFreq(~goodJobVec)),15,'r','filled','o','MarkerEdgeColor','none','MarkerFaceAlpha',0.25);
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
        [yFitDb,yCI] = predict(mdl,xFitLog);
        plot(xFit,yFitDb,':b','LineWidth',2);
        plot(xFit,yCI(:,1),'-.b','LineWidth',1);
        plot(xFit,yCI(:,2),'-.b','LineWidth',1);
        
        % Add the title
        bounds = coefCI(mdl,0.2)-mdl.Coefficients.Estimate;
        bounds = bounds(:,2);
        title([modDirectionLabels{dd} ' ND' NDlabelsAll{nn} sprintf(' [%2.1f, %2.1f]',mdl.Coefficients.Estimate)],'Interpreter','none');

        % Add a plot line to indicate the variance of the residuals
        residuals = mdl.Residuals.Raw;
        E = linspace(log10(1),log10(32),nBins+1);
        binCenters = E(1:nBins)+(E(2)-E(1))/2;
        for rr = 1:nBins
            binStart = max([min(E),E(rr)-E(rr)*(binOverlap/2)]);
            binEnd = min([max(E),E(rr+1)+E(rr+1)*(binOverlap/2)]);
            for kk = 1:2
                switch kk
                    case 1
                        idx = find(and(and(log10(refFreq)>=binStart,log10(refFreq)<=binEnd),testFreqInitial>refFreq));
                    case 2
                        idx = find(and(and(log10(refFreq)>=binStart,log10(refFreq)<=binEnd),testFreqInitial<=refFreq));
                end
                meanVals(rr,kk) = mean(yData(idx));
            end
                        idx = find(and(log10(refFreq)>=binStart,log10(refFreq)<=binEnd));
                varVals(rr) = std(residuals(idx)).^2;
        end
        plot(10.^binCenters,varVals,'o-m','LineWidth',2);        

        % Uncoment these lines to show the bias per bin
        %{
            plot(10.^binCenters,meanVals(:,1),'o-b','LineWidth',2);
            plot(10.^binCenters,meanVals(:,2),'x-b','LineWidth',2);
            plot(10.^binCenters,mean(meanVals,2),'*-b','LineWidth',2);
        %}

        % Report the model fit and CIs
        CIs = coefCI(mdl,0.05);
        fprintf([modDirectionLabels{dd} ' ND' NDlabelsAll{nn} ' mean variance: %2.2f, intercept: %2.2f [%2.2f : %2.2f]; slope: %2.2f [%2.2f : %2.2f]\n' ],mean(varVals),mdl.Coefficients.Estimate(1),CIs(1,:),mdl.Coefficients.Estimate(2),CIs(2,:));


    end
end