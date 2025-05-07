% Ugly hacky code to make info figures for Ruby's VSS 2025 poster

% Housekeeping
%close all
clear

% Get the subject ID
subjectID = 'FLIC_0001';

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

nn = 1; dd = 1;

% Load the psych object for this direction and light level
dataDir = fullfile(subjectDir,[modDirections{dd} '_ND' NDlabelsAll{nn}],experimentName);
psychFileStem = [subjectID '_' modDirections{dd} '_' experimentName ...
    '_' strrep(num2str(targetPhotoreceptorContrast(dd)),'.','x')];
filename = fullfile(dataDir,[psychFileStem '.mat']);
load(filename,'psychObj');

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
testRangedB = psychObj.testRangeDecibels;
goodJobCriterionDb = psychObj.goodJobCriterionDb;
goodJobVec = [psychObj.trialData.goodJob];
proportionGoodjob = sum(goodJobVec)/length(goodJobVec);
fprintf(['Proportion good job ' modDirections{dd} ' ND' NDlabelsAll{nn} ': %2.2f\n'],proportionGoodjob)


%% PLOT LINEAR LINEAR
nexttile();
plot([0.5 60],[0 0],'--k','LineWidth',1.5)
hold on
xFit = linspace(1,100,100)';
plot(xFit,xFit.*db2pow(goodJobCriterionDb)-xFit,':k','LineWidth',1.5)
plot(xFit,xFit./db2pow(goodJobCriterionDb)-xFit,':k','LineWidth',1.5)
xlim([0.5 35])
scatter(refFreq(goodJobVec),testFreq(goodJobVec)-refFreq(goodJobVec),'k','filled','o','MarkerEdgeColor','none','MarkerFaceAlpha',0.25);
scatter(refFreq(~goodJobVec),testFreq(~goodJobVec)-refFreq(~goodJobVec),'r','filled','o','MarkerEdgeColor','none','MarkerFaceAlpha',0.25);
ylim([-30 30])
axis square
a=gca();
a.XTick = [1,2,4,8,16,32];
a.FontName = 'Helvetica';
a.FontSize = 16;
xlabel('Reference Frequency [Hz]', 'FontName', 'Helvetica', 'FontSize', 16)
ylabel('Error [Hz]', 'FontName', 'Helvetica', 'FontSize', 16)
box off

%% PLOT LOG X, LINEAR Y
nexttile();
semilogx([0.5 60],[0 0],'--k','LineWidth',1.5)
hold on
xFitLog = linspace(0,2,100)';
xFit = 10.^(xFitLog);
semilogx(xFit,xFit.*db2pow(goodJobCriterionDb)-xFit,':k','LineWidth',1.5)
semilogx(xFit,xFit./db2pow(goodJobCriterionDb)-xFit,':k','LineWidth',1.5)
xlim([0.5 60])
scatter(refFreq(goodJobVec),testFreq(goodJobVec)-refFreq(goodJobVec),'k','filled','o','MarkerEdgeColor','none','MarkerFaceAlpha',0.25);
scatter(refFreq(~goodJobVec),testFreq(~goodJobVec)-refFreq(~goodJobVec),'r','filled','o','MarkerEdgeColor','none','MarkerFaceAlpha',0.25);
ylim([-30 30])
a=gca();
a.XTick = [1,2,4,8,16,32];
axis square
a=gca();
a.XTick = [1,2,4,8,16,32];
a.FontName = 'Helvetica';
a.FontSize = 16;
xlabel('Reference Frequency [Hz]', 'FontName', 'Helvetica', 'FontSize', 16)
ylabel('Error [Hz]', 'FontName', 'Helvetica', 'FontSize', 16)
box off


%% PLOT LOG X LOG Y
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
a.FontName = 'Helvetica';
a.FontSize = 16;
xlabel('Reference Frequency [Hz]', 'FontName', 'Helvetica', 'FontSize', 16)
ylabel('Error [dB]', 'FontName', 'Helvetica', 'FontSize', 16)
box off


%% PLOT LOG X LOG Y with fits
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


% Add a fit line.
xData = log10(refFreq);
yData = pow2db(testFreq./refFreq);
mdl = fitlm(xData,yData,'RobustOpts','on');
yFitDb = predict(mdl,xFitLog);
plot(xFit,yFitDb,'-b','LineWidth',2);

% Add a plot line to indicate the variance of the residuals
% How many bins to use when calculating the variance across frequency?
nBins = 10;
binOverlap = 0.25;
residuals = mdl.Residuals.Raw;
E = linspace(log10(1),log10(32),nBins+1);
binCenters = E(1:nBins)+(E(2)-E(1))/2;
for rr = 1:nBins
    binStart = max([min(E),E(rr)-E(rr)*(binOverlap/2)]);
    binEnd = min([max(E),E(rr+1)+E(rr+1)*(binOverlap/2)]);
    idx = find(and(log10(refFreq)>=binStart,log10(refFreq)<=binEnd));
    varVals(rr) = std(residuals(idx)).^2;
end
plot(10.^binCenters,varVals,'o-m','LineWidth',2);

xlim([0.5 60])
ylim([-6 6])
axis square
a=gca();
a.XTick = [1,2,4,8,16,32];
a.YTick = [-6 -4 -2 0 2 4 6];
a.FontName = 'Helvetica';
a.FontSize = 16;
xlabel('Reference Frequency [Hz]', 'FontName', 'Helvetica', 'FontSize', 16)
ylabel('Error [dB]', 'FontName', 'Helvetica', 'FontSize', 16)
box off
