
close all

subjectID = 'HERO_gka';
stimPressureSetPSI = [2.13, 3.11, 4.53, 6.62, 9.65, 14.09, 20.56];

dropBoxBaseDir=getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir='BLNK_data';
projectName='combiAir';
experimentName = 'DSCM';

% Set the labels for the high and low stimulus ranges
stimParamLabels = {'stimParamsHi','stimParamsLow'};
% Define the modulation and data directories
subjectDir = fullfile(...
    dropBoxBaseDir,...
    dropBoxSubDir,...,
    projectName,...
    subjectID);
dataDir = fullfile(subjectDir,experimentName);

slopeVals = [];
slopeValCI = [];

% Set up a figure
figHandle = figure();
figuresize(750,250,'units','pt');
tiledlayout(1,5,"TileSpacing","compact",'Padding','tight');


for rr = 3:length(stimPressureSetPSI)

    % Load the low-side measurements
    psychFileStem = [subjectID '_' experimentName ...
        '_refPSI-' num2str(stimPressureSetPSI(rr)) ...
        '_' stimParamLabels{1}];
    filename = fullfile(dataDir,psychFileStem);
    load(filename,'psychObj');

    % Store some of these parameters
    questData = psychObj.questData;
    stimParamsDomainList = psychObj.stimParamsDomainList;
    psiParamsDomainList = psychObj.psiParamsDomainList;

    % Load the high side measurements
    psychFileStem = [subjectID '_' experimentName ...
        '_refPSI-' num2str(stimPressureSetPSI(rr)) ...
        '_' stimParamLabels{2}];
    filename = fullfile(dataDir,psychFileStem);
    load(filename,'psychObj');

    % Combine the two measurement sets
    questData.trialData = [questData.trialData; psychObj.questData.trialData];
    stimParamsDomainList = unique([stimParamsDomainList, psychObj.stimParamsDomainList]);
    nTrials = length(psychObj.questData.trialData);

    % Get the Max Likelihood psi params, temporarily turning off verbosity.
    % Also, lock the mu parameter to be zero.
    lb = [0,min(psiParamsDomainList{2})];
    ub = [0,max(psiParamsDomainList{2})];
    nBoots = 1000;
    storeVerbose = psychObj.verbose;
    psychObj.verbose = false;
    [~, psiParamsFit, psiParamsCI] = psychObj.reportParams('lb',lb,'ub',ub,'nBoots',nBoots);
    psychObj.verbose = storeVerbose;


    % Now the proportion correct for each stimulus type, and the psychometric
    % function fit. Marker transparancy (and size) visualizes number of trials
    % (more opaque -> more trials), while marker color visualizes percent
    % correct (more red -> more correct).
    nexttile
    hold on

    % Get the proportion selected "test" for each stimulus
    stimCounts = qpCounts(qpData(questData.trialData),questData.nOutcomes);
    stim = zeros(length(stimCounts),questData.nStimParams);
    for cc = 1:length(stimCounts)
        stim(cc) = stimCounts(cc).stim;
        nTrials(cc) = sum(stimCounts(cc).outcomeCounts);
        pSelectTest(cc) = stimCounts(cc).outcomeCounts(2)/nTrials(cc);
    end

    % Plot these
    markerSizeIdx = discretize(nTrials,3);
    markerSizeSet = [25,50,100];
    for cc = 1:length(stimCounts)
        scatter(stim(cc),pSelectTest(cc),markerSizeSet(markerSizeIdx(cc)),'o', ...
            'MarkerFaceColor',[pSelectTest(cc) 0 1-pSelectTest(cc)], ...
            'MarkerEdgeColor','k', ...
            'MarkerFaceAlpha',nTrials(cc)/max(nTrials));
        hold on
    end

    % Add the psychometric function
    plotParamsDomainList = linspace(-1.5,1.5,101);
    for cc = 1:length(plotParamsDomainList)
        outcomes = psychObj.questData.qpPF(plotParamsDomainList(cc),psiParamsFit);
        fitCorrect(cc) = outcomes(2);
    end
    plot(plotParamsDomainList,fitCorrect,'-k')

    % Add a marker for the 50% point
    outcomes = psychObj.questData.qpPF(psiParamsFit(1),psiParamsFit);
    plot([psiParamsFit(1), psiParamsFit(1)],[0, outcomes(2)],':k')
    plot([min(plotParamsDomainList), psiParamsFit(1)],[0.5 0.5],':k')

    % Labels and range
    xlim([-1.5 1.5]);
    ylim([-0.1 1.1]);
    if rr == 5
        xlabel('stimulus difference [dB]')
    end
    if rr == 3
        ylabel('proportion pick test as faster');
    end

    % Add a title
    str = sprintf('%2.1f PSI',psychObj.refPuffPSI);
    title(str);
    box off

    % Store the slope of the psychometric function
    slopeVals(rr) = normpdf(0,psiParamsFit(1),psiParamsFit(2));
    slopeValCI(rr,1) = normpdf(0,psiParamsCI(1,1),psiParamsCI(1,2));
    slopeValCI(rr,2) = normpdf(0,psiParamsCI(2,1),psiParamsCI(2,2));

end

figure
figuresize(250,250,'units','pt');

yvals = [mean(slopeVals(3:4)) mean(slopeVals(3:4)) mean(slopeVals([4 6])) mean(slopeVals(6:7)) mean(slopeVals(6:7))];
semilogx(stimPressureSetPSI(3:7),yvals,'-k');
hold on
for rr = 3:length(stimPressureSetPSI)
    semilogx([stimPressureSetPSI(rr) stimPressureSetPSI(rr)],...
        slopeValCI(rr,:),'-k' );
    hold on
    semilogx(stimPressureSetPSI(rr),slopeVals(rr),'or','MarkerSize',15);

end

ylim([0,1.5]);
ylabel('discrimination slope [% resppnse / dB]');
a = gca();
a.XTick = stimPressureSetPSI(3:end);
a.XTickLabel = {'4.5','6.6','9.7','14.1','20.6'};
xlim([3.7,24.9]);
xlabel('Reference stimulus intensity [PSI]')
box off
