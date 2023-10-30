clear
close all

load('/Users/aguirre/Aguirre-Brainard Lab Dropbox/Geoffrey Aguirre/MELA_data/combiLED/HERO_gka1/LightFlux/DMTF/HERO_gka1_LightFlux_DMTF_0x5.mat')

% Remove two bad data points when I accidentally pressed the end
% trial key at the start of the trial. This was trials 131 and 170
trialData = psychObj.trialData;
trialData = trialData([1:130,132:169,171:200]);

% Extract the ref and test frequencies, and
refFreq = [trialData.refFreq];
testFreq = [trialData.testFreq];
refFreqRangeHz = [2 10];

[~,edges] = histcounts(log10(refFreq),10);
Y = discretize(log10(refFreq),edges);
nBins = length(edges)-1;


for bb = 1:nBins
    logVariance(bb) = std(log10(testFreq(Y==bb))).^2;
    linearBias(bb) = mean(testFreq(Y==bb)-refFreq(Y==bb));
    binLabels{bb} = sprintf('%2.1f - %2.1f',round(10^edges(bb),1),round(10.^edges(bb+1),1));
end

figHandle = figure();
figuresize(600, 400,'pt');

tiledlayout(2,3,"TileSpacing","tight","Padding","tight");
nexttile([2 2]);

loglog([1.5 15],[1.5 15],'--k','LineWidth',1.5)
hold on
scatter(refFreq,testFreq,'k','filled','o','MarkerEdgeColor','none','MarkerFaceAlpha',0.25);
xlim([1.5 15])
ylim([1.5 15])
axis square
a=gca();
a.XTick = [2:10];
a.YTick = [2:10];
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
ylabel('Bias [Hz]')
xlim([0.5,nBins+0.5]);
a = gca();
a.XTick = [1:nBins];
a.XTickLabels = binLabels;
box off
