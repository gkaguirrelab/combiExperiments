
% Get the subject ID
subjectID = GetWithDefault('Subject ID','FLIC_xxxx');

% The light levels and directions
NDlabelsAll = {'0x5','3x5'};
modDirections = {'LminusM_wide','LightFlux'};
targetPhotoreceptorContrast = [0.09,0.4];

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
figuresize(600, 400,'pt');
tiledlayout(2,3,"TileSpacing","tight","Padding","tight");

for nn = 1:1 %length(NDlabelsAll)
    for dd = 1:length(modDirections)

        % Load the psych object for this direction and light level
        dataDir = fullfile(subjectDir,[modDirections{dd} '_ND' NDlabelsAll{nn}],experimentName);
        psychFileStem = [subjectID '_' modDirections{dd} '_' experimentName ...
            '_' strrep(num2str(targetPhotoreceptorContrast(dd)),'.','x')];
        filename = fullfile(dataDir,[psychFileStem '.mat']);
        load(filename,'psychObj');


        % Extract the ref and test frequencies, and
        refFreq = [psychObj.trialData.refFreq];
        testFreq = [psychObj.trialData.testFreq];

        [~,edges] = histcounts(log10(refFreq),10);
        Y = discretize(log10(refFreq),edges);
        nBins = length(edges)-1;

        for bb = 1:nBins
            logVariance(bb) = std(log10(testFreq(Y==bb))).^2;
            linearBias(bb) = mean(testFreq(Y==bb)-refFreq(Y==bb));
            binLabels{bb} = sprintf('%2.1f - %2.1f',round(10^edges(bb),1),round(10.^edges(bb+1),1));
        end


        nexttile();

        loglog([1.5 15],[1.5 15],'--k','LineWidth',1.5)
        hold on
        scatter(refFreq,testFreq,'k','filled','o','MarkerEdgeColor','none','MarkerFaceAlpha',0.25);
        xlim([0.5 60])
        ylim([0.5 60])
        axis square
        a=gca();
        a.XTick = [1,2,4,8,16,32];
        a.YTick = [1,2,4,8,16,32];
        xlabel('Reference Frequency [Hz]')
        ylabel('Match Frequency [Hz]')
        box off
        title(modDirections{dd})
    end
end