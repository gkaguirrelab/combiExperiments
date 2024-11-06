
% Housekeeping
close all
clear

% Get the subject ID
subjectID = GetWithDefault('Subject ID','FLIC_xxxx');

% The light levels and directions
NDlabelsAll = {'0x5','3x5'};
modDirections = {'LminusM_wide','LightFlux'};
targetPhotoreceptorContrast = [0.09,0.4];
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

refFreq = [];
testFreq = [];

% This plots the test and reference frequencies from all four conditions
% of the experiment on a single graph. 
for nn = 1:length(NDlabelsAll)
    for dd = 1:length(modDirections)

        % Load the psych object for this direction and light level
        dataDir = fullfile(subjectDir,[modDirections{dd} '_ND' NDlabelsAll{nn}],experimentName);
        psychFileStem = [subjectID '_' modDirections{dd} '_' experimentName ...
            '_' strrep(num2str(targetPhotoreceptorContrast(dd)),'.','x')];
        filename = fullfile(dataDir,[psychFileStem '.mat']);
        load(filename,'psychObj');

        % Extract the ref and test frequencies
        thisRefFreq = [psychObj.trialData.refFreq];
        thisTestFreq = [psychObj.trialData.testFreq];

         % Append the ref and test frequencies to a list
        refFreq = [refFreq, thisRefFreq];
        testFreq = [testFreq, thisTestFreq];

    end
end


% obtain a linear bias and variance across frequency
[~,edges] = histcounts(log10(refFreq),7);
Y = discretize(log10(refFreq),edges);
nBins = length(edges)-1;

for bb = 1:nBins
    logVariance(bb) = std(log10(testFreq(Y==bb))).^2;
    linearBias(bb) = median(testFreq(Y==bb)-refFreq(Y==bb));
    binLabels{bb} = sprintf('%2.1f - %2.1f',round(10^edges(bb),1),round(10.^edges(bb+1),1));
end

figHandle = figure();
figuresize(600, 400,'pt');

tiledlayout(2,3,"TileSpacing","tight","Padding","tight");
nexttile([2 2]);

loglog([.25 50],[.25 50],'--k','LineWidth',1.5)
hold on
scatter(refFreq,testFreq,'k','filled','o','MarkerEdgeColor','none','MarkerFaceAlpha',0.25);
xlim([.5 60])
ylim([.5 60])
axis square
a=gca();
a.XTick = [0.5 1 2 4 8 16 32];
a.YTick = [0.5 1 2 4 8 16 32];
xlabel('Reference Frequency [Hz]')
ylabel('Match Frequency [Hz]')
box off

nexttile
pp = csaps(1:nBins,logVariance,9e-2);
fnplt(pp,'-r');
hold on
scatter(1:nBins,logVariance,'filled','o','MarkerEdgeColor','none','MarkerFaceColor',[0.5 0.5 0.5])
axis square
ylabel('Variance log match freq')
xlim([0.5,nBins+0.5]);
a = gca();
a.XTick = [1:nBins];
a.XTickLabels = '';
box off

nexttile
pp = csaps(1:nBins,linearBias,1e-1);
fnplt(pp,'-r');
hold on
scatter(1:nBins,linearBias,'filled','o','MarkerEdgeColor','none','MarkerFaceColor',[0.5 0.5 0.5])
axis square
xlabel('Frequency bin [Hz]')
ylabel('Median bias [Hz]')
xlim([0.5,nBins+0.5]);
a = gca();
a.XTick = [1:nBins];
a.XTickLabels = binLabels;
box off

