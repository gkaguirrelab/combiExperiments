function output = individualFitsAnalysis(options)
%Performs statistical analysis and visualization of
% sigma fit parameters (sigmaTest and sigmaRef) from dichoptic flicker experiments.
%
%   INDIVIDUALFITSANALYSIS(OPTIONS) loads model fit parameters across experimental
%   conditions (Contrasts x Light Levels x Frequencies) for Migraine and Control
%   groups (or super-subjects), generates comparative figures, and conducts
%   omnibus ANOVAs with FDR-corrected group follow-up t-tests.
%
%   INPUT OPTIONS (Name-Value Pairs):
%     barPlot      - (Logical) Generate bar charts comparing sigma values across
%                    contrast/light conditions and group difference interactions.
%                    Default: true
%     fVal         - (Logical) Plot negative log-likelihood (fit quality) distributions
%                    and condition-wise comparisons. Default: true
%     anova        - (Logical) Run 5-way nested mixed-effects ANOVAs (Subject nested
%                    in Group) for both sigmaTest and sigmaRef, and plot fit
%                    parameter distributions. Default: true
%     superSubj    - (Logical) Flag to load pooled "super-subject" data instead
%                    of individual subject fit files. Default: false
%     effectOfFreq - (Logical) Plot main effect of reference frequency on sigma
%                    parameters averaged across groups or conditions. Default: true
arguments
    options.barPlot (1,1) logical = true
    options.beeSwarm (1,1) logical = true
    options.fVal (1,1) logical = true
    options.anova (1,1) logical = true
    options.superSubj (1,1) logical = false
    options.effectOfFreq (1,1) logical = true
    options.sigmaTest (1,1) logical = true
end

%% load data
%set up paths
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir = 'FLIC_analysis';
projectName = 'dichopticFlicker';
experimentName = 'sigmaData';
dataDir = fullfile(dropBoxBaseDir, dropBoxSubDir, projectName, experimentName);

if options.superSubj
    filePath = fullfile(dataDir, '30_superSubjSigmaFitsConstrained.mat');
else
    migraineFilePath = fullfile(dataDir, '15Migrainer_individualSigmaFits.mat');
    controlFilePath  = fullfile(dataDir, '15Control_individualSigmaFits.mat');
end

%load
if options.superSubj
    fits = load(filePath);
    controlCells  = squeeze(fits.sigmaPooled(1,:,:,:));
    migraineCells = squeeze(fits.sigmaPooled(2,:,:,:));
    
    [nContrasts, nLightLevels, nFreqs] = size(controlCells);
    
    sigmaTestC = zeros(1,nContrasts,nLightLevels,nFreqs);
    sigmaRefC  = zeros(1,nContrasts,nLightLevels,nFreqs);
    sigmaTestM = zeros(1,nContrasts,nLightLevels,nFreqs);
    sigmaRefM  = zeros(1,nContrasts,nLightLevels,nFreqs);
    
    for c = 1:nContrasts
        for l = 1:nLightLevels
            for f = 1:nFreqs
                valsC = controlCells{c,l,f};   
                valsM = migraineCells{c,l,f};
                sigmaTestC(1,c,l,f) = valsC(1);
                sigmaRefC(1,c,l,f)  = valsC(2);
                sigmaTestM(1,c,l,f) = valsM(1);
                sigmaRefM(1,c,l,f)  = valsM(2);
            end
        end
    end
    
    nSubjC = 1;
    nSubjM = 1;
else
    migraineFits = load(migraineFilePath);
    controlFits  = load(controlFilePath);
    
    nSubjM = size(migraineFits.sigmaRefMatrix,1);
    nSubjC = size(controlFits.sigmaRefMatrix,1);
    nContrasts = size(migraineFits.sigmaRefMatrix,2);
    nLightLevels = size(migraineFits.sigmaRefMatrix,3);
    nFreqs = size(migraineFits.sigmaRefMatrix,4);
    
    sigmaRefM = migraineFits.sigmaRefMatrix;
    sigmaRefC = controlFits.sigmaRefMatrix;
    sigmaTestM = migraineFits.sigmaTestMatrix;
    sigmaTestC = controlFits.sigmaTestMatrix;
end

contrastLabels = {'Low Contrast', 'High Contrast'};
lightLabels    = {'Low Light', 'High Light'};

if options.superSubj
    refFreqHz = fits.refFreqHz;
else
    refFreqHz = migraineFits.refFreqHz;
end

%% Global Color Palette Definitions (Magenta/Plum & Slate-Teal Blue)
colMigraineHigh = [0.72 0.22 0.48]; 
colMigraineLow  = [0.88 0.55 0.72]; 
colControlHigh  = [0.18 0.48 0.62]; 
colControlLow   = [0.55 0.76 0.85]; 

%% Calculate Mean and SEM
muSigmaTestC  = squeeze(mean(mean(sigmaTestC,  4),1));
muSigmaTestM   = squeeze(mean(mean(sigmaTestM,  4),1));
semSigmaTestC = squeeze(std(mean(sigmaTestC,  4),  [], 1) ./ sqrt(nSubjC));
semSigmaTestM  = squeeze(std(mean(sigmaTestM,  4), [], 1) ./ sqrt(nSubjM));
muSigmaRefC  = squeeze(mean(mean(sigmaRefC,  4),1));
muSigmaRefM   = squeeze(mean(mean(sigmaRefM,  4),1));
semSigmaRefC = squeeze(std(mean(sigmaRefC,  4),  [], 1) ./ sqrt(nSubjC));
semSigmaRefM  = squeeze(std(mean(sigmaRefM,  4), [], 1) ./ sqrt(nSubjM));

%% 2x2 Square Grid Plot for Sigma Test
figTest = figure('Color', 'w', 'Name', 'Sigma Test Across Conditions');
figTest.Units = 'pixels';
figTest.Position = [100 100 900 900];
panelIdx = 1;
for l = 1:2 
    for c = 1:2 
        subplot(2, 2, panelIdx);
        ax = gca;
        set(ax, 'FontSize', 14, 'FontName', 'Helvetica');
        hold on;
        
        mMean = squeeze(mean(sigmaTestM(:,c,l,:), 1));
        mSEM  = squeeze(std(sigmaTestM(:,c,l,:), [], 1)) / sqrt(nSubjM);
        cMean = squeeze(mean(sigmaTestC(:,c,l,:), 1));
        cSEM  = squeeze(std(sigmaTestC(:,c,l,:), [], 1)) / sqrt(nSubjC);
        
        errorbar(refFreqHz, mMean, mSEM, '-o', 'Color', colMigraineHigh, ...
            'MarkerFaceColor', colMigraineHigh, 'LineWidth', 1.8, 'MarkerSize', 11);
        errorbar(refFreqHz, cMean, cSEM, '-s', 'Color', colControlHigh, ...
            'MarkerFaceColor', colControlHigh, 'LineWidth', 1.8, 'MarkerSize', 11);
        
        if l == 1
            xl = [min(refFreqHz)*0.85, max(refFreqHz)*1.15];
            p = patch([xl(1) xl(2) xl(2) xl(1)], [0 0 4 4], ...
                [0.92 0.92 0.92], 'EdgeColor', 'none', 'FaceAlpha', 0.5);
            uistack(p, 'bottom');
        end
        
        xlabel('Reference Frequency (Hz)');
        ylabel('$\sigma_{test}$', 'Interpreter', 'latex', 'FontSize', 18);
        title(sprintf('%s | %s', lightLabels{l}, contrastLabels{c}));
        ylim([0 4]);
        xlim([min(refFreqHz)*0.9, max(refFreqHz)*1.1]);
        xticks([10 13 17 23 30]);
        yticks(0:4);
        axis square;
        box off; grid off;
        set(ax, 'XScale', 'log');
        
        if panelIdx == 1
            hL_M = plot(NaN, NaN, '-o', 'Color', colMigraineHigh, ...
                'MarkerFaceColor', colMigraineHigh, 'LineWidth', 1.8, 'MarkerSize', 11);
            hL_C = plot(NaN, NaN, '-s', 'Color', colControlHigh, ...
                'MarkerFaceColor', colControlHigh, 'LineWidth', 1.8, 'MarkerSize', 11);
            
            lgd = legend([hL_M, hL_C], {'Migraine', 'Control'}, ...
                'Location', 'northwest', 'Box', 'off');
            lgd.ItemTokenSize = [30, 18];
        end
        
        panelIdx = panelIdx + 1;
    end
end

%% 2x2 Square Grid Plot for Sigma Ref
figRef = figure('Color', 'w', 'Name', 'Sigma Ref Across Conditions');
figRef.Units = 'pixels';
figRef.Position = [100 100 900 900];
panelIdx = 1;
for l = 1:2 
    for c = 1:2 
        subplot(2, 2, panelIdx);
        ax = gca;
        set(ax, 'FontSize', 14, 'FontName', 'Helvetica');
        hold on;
        
        mMean = squeeze(mean(sigmaRefM(:,c,l,:), 1));
        mSEM  = squeeze(std(sigmaRefM(:,c,l,:), [], 1)) / sqrt(nSubjM);
        cMean = squeeze(mean(sigmaRefC(:,c,l,:), 1));
        cSEM  = squeeze(std(sigmaRefC(:,c,l,:), [], 1)) / sqrt(nSubjC);
        
        errorbar(refFreqHz, mMean, mSEM, '-o', 'Color', colMigraineHigh, ...
            'MarkerFaceColor', colMigraineHigh, 'LineWidth', 1.8, 'MarkerSize', 11);
        errorbar(refFreqHz, cMean, cSEM, '-s', 'Color', colControlHigh, ...
            'MarkerFaceColor', colControlHigh, 'LineWidth', 1.8, 'MarkerSize', 11);
        
        if l == 1
            xl = [min(refFreqHz)*0.85, max(refFreqHz)*1.15];
            p = patch([xl(1) xl(2) xl(2) xl(1)], [0 0 4 4], ...
                [0.92 0.92 0.92], 'EdgeColor', 'none', 'FaceAlpha', 0.5);
            uistack(p, 'bottom');
        end
        
        xlabel('Reference Frequency (Hz)');
        ylabel('$\sigma_{ref}$', 'Interpreter', 'latex', 'FontSize', 18);
        title(sprintf('%s | %s', lightLabels{l}, contrastLabels{c}));
        ylim([0 2]);
        xlim([min(refFreqHz)*0.9, max(refFreqHz)*1.1]);
        xticks([10 13 17 23 30]);
        yticks(0:0.5:2);
        axis square;
        box off; grid off;
        set(ax, 'XScale', 'log');
        
        if panelIdx == 1
            hL_M = plot(NaN, NaN, '-o', 'Color', colMigraineHigh, ...
                'MarkerFaceColor', colMigraineHigh, 'LineWidth', 1.8, 'MarkerSize', 11);
            hL_C = plot(NaN, NaN, '-s', 'Color', colControlHigh, ...
                'MarkerFaceColor', colControlHigh, 'LineWidth', 1.8, 'MarkerSize', 11);
            
            lgd = legend([hL_M, hL_C], {'Migraine', 'Control'}, ...
                'Location', 'northeast', 'Box', 'off');
            lgd.ItemTokenSize = [30, 18];
        end
        
        panelIdx = panelIdx + 1;
    end
end

%% Poster Plot: Effect of Frequency across combined groups
if options.effectOfFreq
    lightLevel    = 2; 
    contrastLevel = 2; 
    
    mData = squeeze(sigmaTestM(:,contrastLevel,lightLevel,:));
    cData = squeeze(sigmaTestC(:,contrastLevel,lightLevel,:));
    allData = [mData; cData];
    
    muSigma = mean(allData,1);
    semSigma = std(allData,[],1) ./ sqrt(size(allData,1));
    
    fig = figure('Color','w');
    fig.Units = 'pixels';
    fig.Position = [100 100 1400 450];
    set(fig,'InvertHardcopy','off');
    
    ax = gca;
    ax.FontName = 'Helvetica';
    ax.FontSize = 35;
    ax.LineWidth = 1.5;
    hold on;
    
    if options.beeSwarm && ~options.superSubj
        nTotalSubj = size(allData, 1);
        jitterWidth = 0.04;
        for fIdx = 1:length(refFreqHz)
            fVal = refFreqHz(fIdx);
            yVals = allData(:, fIdx);
            xJittered = fVal .* (1 + (rand(nTotalSubj, 1) - 0.5) * jitterWidth);
            
            scatter(xJittered, yVals, 65, ...
                'MarkerFaceColor', [0.35 0.35 0.35], ...
                'MarkerEdgeColor', 'none', ...
                'MarkerFaceAlpha', 0.35);
        end
    end
    
    h1 = errorbar(refFreqHz, muSigma, semSigma, ...
        '-', 'Color', 'k', 'LineWidth', 2.5, 'CapSize', 12, ...
        'Marker', 'o', 'MarkerSize', 22, 'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'w');
    
    uistack(h1,'top');
    
    xlabel('Reference Frequency (Hz)', 'FontSize',35);
    ylabel('$\sigma_{test}$', 'Interpreter', 'latex', 'FontSize',45);
    xlim([min(refFreqHz)*0.9, max(refFreqHz)*1.1]);
    ylim([0 4]);
    set(gca,'XScale','log');
    grid off;
    box off;
    set(gca,'XTick',[10 13 17 23 30]);
end

%% Plots to examine main effect of frequency by group
if options.effectOfFreq
    sigmaTestData = cat(1, sigmaTestM, sigmaTestC);
    sigmaRefData  = cat(1, sigmaRefM, sigmaRefC);
    
    nMigraine = size(sigmaTestM,1);
    groupLabels = [ones(nMigraine,1); 2*ones(size(sigmaTestC,1),1)];
    groups = unique(groupLabels);
    
    nFreqs = length(refFreqHz);
    meanSigmaTest = zeros(length(groups), nFreqs);
    semSigmaTest  = zeros(length(groups), nFreqs);
    meanSigmaRef  = zeros(length(groups), nFreqs);
    semSigmaRef   = zeros(length(groups), nFreqs);
    
    for g = 1:length(groups)
        idx = groupLabels == groups(g);
        dataTest = squeeze(mean(mean(sigmaTestData(idx,:,:,:),3),2));
        dataRef  = squeeze(mean(mean(sigmaRefData(idx,:,:,:),3),2));
        
        if options.superSubj
            meanSigmaTest(g,:) = dataTest; semSigmaTest(g,:) = nan;
            meanSigmaRef(g,:)  = dataRef;  semSigmaRef(g,:)  = nan;
        else
            meanSigmaTest(g,:) = mean(dataTest,1);
            semSigmaTest(g,:)  = std(dataTest,0,1)/sqrt(sum(idx));
            meanSigmaRef(g,:)  = mean(dataRef,1);
            semSigmaRef(g,:)   = std(dataRef,0,1)/sqrt(sum(idx));
        end
    end
    
    % Plot Sigma Test
    figure('Color','w'); hold on;
    if options.superSubj
        plot(refFreqHz, meanSigmaTest(1,:), '-o', ...
            'Color', colMigraineHigh, 'MarkerFaceColor', colMigraineHigh, ...
            'LineWidth', 1.8, 'MarkerSize', 11, 'DisplayName','Migraine');
        plot(refFreqHz, meanSigmaTest(2,:), '-s', ...
            'Color', colControlHigh, 'MarkerFaceColor', colControlHigh, ...
            'LineWidth', 1.8, 'MarkerSize', 11, 'DisplayName','Control');
    else
        errorbar(refFreqHz, meanSigmaTest(1,:), semSigmaTest(1,:), '-o', ...
            'Color', colMigraineHigh, 'MarkerFaceColor', colMigraineHigh, 'LineWidth', 1.8, 'MarkerSize', 11, 'DisplayName','Migraine');
        errorbar(refFreqHz, meanSigmaTest(2,:), semSigmaTest(2,:), '-s', ...
            'Color', colControlHigh, 'MarkerFaceColor', colControlHigh, 'LineWidth', 1.8, 'MarkerSize', 11, 'DisplayName','Control');
    end
    set(gca,'XScale','log');
    xlabel('Reference Frequency (Hz)'); ylabel('Sigma Test');
    ylim([0 4]); title('Frequency vs Sigma Test');
    xticks([10 13 17 23 30]);
    lgd = legend('Location','northwest', 'Box', 'off'); grid off; box off;
    lgd.ItemTokenSize = [30, 18];
    xlim([min(refFreqHz)*0.9, max(refFreqHz)*1.1]);
    
    % Plot Sigma Ref
    figure('Color','w'); hold on;
    if options.superSubj
        plot(refFreqHz, meanSigmaRef(1,:), '-o', ...
            'Color', colMigraineHigh, 'MarkerFaceColor', colMigraineHigh, ...
            'LineWidth', 1.8, 'MarkerSize', 11, 'DisplayName','Migraine');
        plot(refFreqHz, meanSigmaRef(2,:), '-s', ...
            'Color', colControlHigh, 'MarkerFaceColor', colControlHigh, ...
            'LineWidth', 1.8, 'MarkerSize', 11, 'DisplayName','Control');
    else
        errorbar(refFreqHz, meanSigmaRef(1,:), semSigmaRef(1,:), '-o', ...
            'Color', colMigraineHigh, 'MarkerFaceColor', colMigraineHigh, 'LineWidth', 1.8, 'MarkerSize', 11, 'DisplayName','Migraine');
        errorbar(refFreqHz, meanSigmaRef(2,:), semSigmaRef(2,:), '-s', ...
            'Color', colControlHigh, 'MarkerFaceColor', colControlHigh, 'LineWidth', 1.8, 'MarkerSize', 11, 'DisplayName','Control');
    end
    set(gca,'XScale','log');
    xlabel('Reference Frequency (Hz)'); ylabel('Sigma Ref');
    ylim([0 4]);
    title('Frequency vs Sigma Ref');
    xticks([10 13 17 23 30]);
    lgd = legend('Location','northwest', 'Box', 'off'); grid off; box off;
    lgd.ItemTokenSize = [30, 18];
    xlim([min(refFreqHz)*0.9, max(refFreqHz)*1.1]);
end

%% Bar plot: Re-ordered by Contrast
sigmaTest = options.sigmaTest;
if options.barPlot
    reorderIdx = [1 3 2 4];
    lowContrastPos    = [1 2];
    
    if sigmaTest
        barData = [muSigmaTestC(:), muSigmaTestM(:)];
        errData = [semSigmaTestC(:), semSigmaTestM(:)];
    else
        barData = [muSigmaRefC(:), muSigmaRefM(:)];
        errData = [semSigmaRefC(:), semSigmaRefM(:)];
    end
    
    barData = barData(reorderIdx, :);
    errData = errData(reorderIdx, :);
    
    fig = figure('Color','w');
    fig.Units = 'pixels';
    fig.Position = [100 100 1800 600];
    set(fig,'InvertHardcopy','off');
    
    ax = gca;
    ax.FontName = 'Helvetica';
    ax.FontSize = 35;
    ax.LineWidth = 1.5;
    hold on;
    
    yMaxLimit = if_then(options.beeSwarm, 3, 2.5);
    
    patch([0.5 1.5 1.5 0.5], [0 0 yMaxLimit yMaxLimit], [0.9 0.9 0.9], ...
        'EdgeColor', 'none', 'FaceAlpha', 0.5);
    patch([2.5 3.5 3.5 2.5], [0 0 yMaxLimit yMaxLimit], [0.9 0.9 0.9], ...
        'EdgeColor', 'none', 'FaceAlpha', 0.5);
    
    b = bar(barData, 'grouped');
    b(1).FaceColor = 'flat';
    b(2).FaceColor = 'flat';
    
    for g = 1:4
        if ismember(g, lowContrastPos)
            b(1).CData(g,:) = colControlLow;
            b(2).CData(g,:) = colMigraineLow;
        else
            b(1).CData(g,:) = colControlHigh;
            b(2).CData(g,:) = colMigraineHigh;
        end
    end
    
    b(1).EdgeColor = 'none';
    b(2).EdgeColor = 'none';
    
    % Custom Solid Outlines
    for iBar = 1:2
        for g = 1:4
            xCenter = b(iBar).XEndPoints(g);
            nBars = size(barData,2);
            groupWidth = min(0.8, nBars/(nBars + 1.5));
            width = groupWidth / nBars - 0.06;
            y = barData(g,iBar);
            
            if iBar == 1
                edgeColor = if_then(ismember(g, lowContrastPos), colControlLow * 0.8, colControlHigh * 0.7);
            else
                edgeColor = if_then(ismember(g, lowContrastPos), colMigraineLow * 0.8, colMigraineHigh * 0.7);
            end
            
            rectangle('Position', ...
                [xCenter - width/2, 0, width, y], ...
                'EdgeColor', edgeColor, ...
                'LineStyle', '-', ...
                'LineWidth', 2, ...
                'FaceColor', 'none');
        end
    end
    
    % Error Bars
    if options.superSubj
        errData(:) = NaN;
    else
        for i = 1:numel(b)
            errorbar(b(i).XEndPoints, b(i).YData, errData(:,i), ...
                'k', 'linestyle', 'none', 'LineWidth', 2.5);
        end
    end
    
    % Bee Swarm Overlay
    if options.beeSwarm && ~options.superSubj
        if sigmaTest
            cDataAvg = squeeze(mean(sigmaTestC, 4));
            mDataAvg = squeeze(mean(sigmaTestM, 4));
        else
            cDataAvg = squeeze(mean(sigmaRefC, 4));
            mDataAvg = squeeze(mean(sigmaRefM, 4));
        end
        
        rawControl  = cDataAvg(:, reorderIdx);
        rawMigraine = mDataAvg(:, reorderIdx);
        
        xControlCenters  = b(1).XEndPoints;
        xMigraineCenters = b(2).XEndPoints;
        
        for g = 1:4
            cEdge = if_then(ismember(g, lowContrastPos), colControlLow * 0.7, colControlHigh * 0.6);
            mEdge = if_then(ismember(g, lowContrastPos), colMigraineLow * 0.7, colMigraineHigh * 0.6);
            
            yValC = rawControl(:, g);
            xC = xControlCenters(g);
            swarmchart(repmat(xC, size(yValC)), yValC, 60, ...
                'MarkerFaceColor', cEdge, ...
                'MarkerEdgeColor', cEdge * 0.7, ...
                'MarkerFaceAlpha', 0.85, ...
                'XJitter', 'density', ...
                'XJitterWidth', 0.2);
            
            yValM = rawMigraine(:, g);
            xM = xMigraineCenters(g);
            swarmchart(repmat(xM, size(yValM)), yValM, 60, ...
                'MarkerFaceColor', mEdge, ...
                'MarkerEdgeColor', mEdge * 0.7, ...
                'MarkerFaceAlpha', 0.85, ...
                'XJitter', 'density', ...
                'XJitterWidth', 0.2);
        end
    end
    
    set(gca, 'Layer', 'top', 'Box', 'off');
    ylabel(if_then(sigmaTest, '$\sigma_{test}$', '$\sigma_{ref}$'), ...
        'Interpreter','latex', 'FontSize',45, 'FontName','Helvetica');
    
    ylim([0 yMaxLimit]);
    xlim([0.5, 4.5]);
    xticks([]);
    
    lgd = legend([b(1), b(2)], {'Control', 'Migraine'}, ...
        'Location', 'Northwest');
    lgd.FontSize = 32; lgd.FontName = 'Helvetica'; lgd.Box = 'off';
    
    lightNames = {'Low Light', 'High Light', 'Low Light', 'High Light'};
    yLightSub = -0.15;
    for i = 1:4
        midPoint = (b(1).XEndPoints(i) + b(2).XEndPoints(i)) / 2;
        text(midPoint, yLightSub, lightNames{i}, ...
            'HorizontalAlignment', 'center', 'FontSize', 32, 'Rotation', 0);
    end
    
    yContrastMain = -0.35;
    text(1.5, yContrastMain, 'Low Contrast', 'HorizontalAlignment', 'center', ...
        'FontWeight', 'bold', 'FontSize', 35, 'Clipping', 'off');
    text(3.5, yContrastMain, 'High Contrast', 'HorizontalAlignment', 'center', ...
        'FontWeight', 'bold', 'FontSize', 35, 'Clipping', 'off');
end

%% Delta Sigma Bar Plots (High - Low Light) with Shared Symmetrical Limits (No Cutoff)
if options.barPlot && ~options.superSubj
    mTestLight = squeeze(mean(sigmaTestM, 4));
    cTestLight = squeeze(mean(sigmaTestC, 4));
    mRefLight  = squeeze(mean(sigmaRefM, 4));
    cRefLight  = squeeze(mean(sigmaRefC, 4));
    
    cDiffTest_LowC  = cTestLight(:, 1, 2) - cTestLight(:, 1, 1);
    mDiffTest_LowC  = mTestLight(:, 1, 2) - mTestLight(:, 1, 1);
    cDiffTest_HighC = cTestLight(:, 2, 2) - cTestLight(:, 2, 1);
    mDiffTest_HighC = mTestLight(:, 2, 2) - mTestLight(:, 2, 1);
    
    cDiffRef_LowC   = cRefLight(:, 1, 2) - cRefLight(:, 1, 1);
    mDiffRef_LowC   = mRefLight(:, 1, 2) - mRefLight(:, 1, 1);
    cDiffRef_HighC  = cRefLight(:, 2, 2) - cRefLight(:, 2, 1);
    mDiffRef_HighC  = mRefLight(:, 2, 2) - mRefLight(:, 2, 1);
    
    allDeltaVals = [cDiffTest_LowC; mDiffTest_LowC; cDiffTest_HighC; mDiffTest_HighC; ...
                    cDiffRef_LowC; mDiffRef_LowC; cDiffRef_HighC; mDiffRef_HighC];
    maxAbsDelta = max(abs(allDeltaVals)) * 1.15;
    
    deltaTestMeans = [mean(cDiffTest_LowC),  mean(mDiffTest_LowC); ...
                      mean(cDiffTest_HighC), mean(mDiffTest_HighC)];
    deltaTestSEMs  = [std(cDiffTest_LowC)/sqrt(nSubjC),  std(mDiffTest_LowC)/sqrt(nSubjM); ...
                      std(cDiffTest_HighC)/sqrt(nSubjC), std(mDiffTest_HighC)/sqrt(nSubjM)];
    
    figDeltaT = figure('Color','w','Name','Delta Sigma Test by Contrast');
    figDeltaT.Units = 'pixels'; figDeltaT.Position = [100 100 650 600];
    ax = gca; ax.FontName = 'Helvetica'; ax.FontSize = 26; ax.LineWidth = 1.5; hold on;
    
    bT = bar(deltaTestMeans, 'grouped', 'BarWidth', 0.7);
    bT(1).FaceColor = 'flat'; bT(2).FaceColor = 'flat';
    bT(1).CData(1,:) = colControlLow;  bT(1).CData(2,:) = colControlHigh;
    bT(2).CData(1,:) = colMigraineLow; bT(2).CData(2,:) = colMigraineHigh;
    
    for i = 1:numel(bT)
        errorbar(bT(i).XEndPoints, bT(i).YData, deltaTestSEMs(:,i), 'k', 'LineStyle', 'none', 'LineWidth', 2.5);
    end
    
    if options.beeSwarm
        swarmchart(repmat(bT(1).XEndPoints(1), size(cDiffTest_LowC)), cDiffTest_LowC, 45, 'MarkerFaceColor', colControlLow*0.7, 'MarkerEdgeColor', colControlLow*0.7, 'XJitter', 'density', 'XJitterWidth', 0.12);
        swarmchart(repmat(bT(2).XEndPoints(1), size(mDiffTest_LowC)), mDiffTest_LowC, 45, 'MarkerFaceColor', colMigraineLow*0.7, 'MarkerEdgeColor', colMigraineLow*0.7, 'XJitter', 'density', 'XJitterWidth', 0.12);
        swarmchart(repmat(bT(1).XEndPoints(2), size(cDiffTest_HighC)), cDiffTest_HighC, 45, 'MarkerFaceColor', colControlHigh*0.7, 'MarkerEdgeColor', colControlHigh*0.7, 'XJitter', 'density', 'XJitterWidth', 0.12);
        swarmchart(repmat(bT(2).XEndPoints(2), size(mDiffTest_HighC)), mDiffTest_HighC, 45, 'MarkerFaceColor', colMigraineHigh*0.7, 'MarkerEdgeColor', colMigraineHigh*0.7, 'XJitter', 'density', 'XJitterWidth', 0.12);
    end
    
    set(gca, 'XTick', 1:2, 'XTickLabel', {'Low Contrast', 'High Contrast'}, 'FontSize', 22);
    ylabel('$\Delta \sigma_{\mathrm{\it{test}}}$ (High - Low Light)', 'Interpreter', 'latex', 'FontSize', 26);
    ylim([-maxAbsDelta maxAbsDelta]); box off; grid off;
    
    hLegControl  = patch(NaN, NaN, colControlHigh, 'EdgeColor', 'none');
    hLegMigraine = patch(NaN, NaN, colMigraineHigh, 'EdgeColor', 'none');
    lgd = legend([hLegControl, hLegMigraine], {'Control', 'Migraine'}, 'Location', 'northeast', 'Box', 'off');
    lgd.FontSize = 20; box off; xlim([0.4 2.6]);
    
    deltaRefMeans = [mean(cDiffRef_LowC),  mean(mDiffRef_LowC); ...
                     mean(cDiffRef_HighC), mean(mDiffRef_HighC)];
    deltaRefSEMs  = [std(cDiffRef_LowC)/sqrt(nSubjC),  std(mDiffRef_LowC)/sqrt(nSubjM); ...
                     std(cDiffRef_HighC)/sqrt(nSubjC), std(mDiffRef_HighC)/sqrt(nSubjM)];
    
    figDeltaR = figure('Color','w','Name','Delta Sigma Ref by Contrast');
    figDeltaR.Units = 'pixels'; figDeltaR.Position = [100 100 650 600];
    ax = gca; ax.FontName = 'Helvetica'; ax.FontSize = 26; ax.LineWidth = 1.5; hold on;
    
    bR = bar(deltaRefMeans, 'grouped', 'BarWidth', 0.7);
    bR(1).FaceColor = 'flat'; bR(2).FaceColor = 'flat';
    bR(1).CData(1,:) = colControlLow;  bR(1).CData(2,:) = colControlHigh;
    bR(2).CData(1,:) = colMigraineLow; bR(2).CData(2,:) = colMigraineHigh;
    
    for i = 1:numel(bR)
        errorbar(bR(i).XEndPoints, bR(i).YData, deltaRefSEMs(:,i), 'k', 'LineStyle', 'none', 'LineWidth', 2.5);
    end
    
    if options.beeSwarm
        swarmchart(repmat(bR(1).XEndPoints(1), size(cDiffRef_LowC)), cDiffRef_LowC, 45, 'MarkerFaceColor', colControlLow*0.7, 'MarkerEdgeColor', colControlLow*0.7, 'XJitter', 'density', 'XJitterWidth', 0.12);
        swarmchart(repmat(bR(2).XEndPoints(1), size(mDiffRef_LowC)), mDiffRef_LowC, 45, 'MarkerFaceColor', colMigraineLow*0.7, 'MarkerEdgeColor', colMigraineLow*0.7, 'XJitter', 'density', 'XJitterWidth', 0.12);
        swarmchart(repmat(bR(1).XEndPoints(2), size(cDiffRef_HighC)), cDiffRef_HighC, 45, 'MarkerFaceColor', colControlHigh*0.7, 'MarkerEdgeColor', colControlHigh*0.7, 'XJitter', 'density', 'XJitterWidth', 0.12);
        swarmchart(repmat(bR(2).XEndPoints(2), size(mDiffRef_HighC)), mDiffRef_HighC, 45, 'MarkerFaceColor', colMigraineHigh*0.7, 'MarkerEdgeColor', colMigraineHigh*0.7, 'XJitter', 'density', 'XJitterWidth', 0.12);
    end
    
    set(gca, 'XTick', 1:2, 'XTickLabel', {'Low Contrast', 'High Contrast'}, 'FontSize', 22);
    ylabel('$\Delta \sigma_{\mathrm{\it{ref}}}$ (High - Low Light)', 'Interpreter', 'latex', 'FontSize', 26);
    ylim([-maxAbsDelta maxAbsDelta]); box off; grid off;
    
    hLegControl  = patch(NaN, NaN, colControlHigh, 'EdgeColor', 'none');
    hLegMigraine = patch(NaN, NaN, colMigraineHigh, 'EdgeColor', 'none');
    lgd = legend([hLegControl, hLegMigraine], {'Control', 'Migraine'}, 'Location', 'northeast', 'Box', 'off');
    lgd.FontSize = 20; box off; xlim([0.4 2.6]);
end

%% Unified Group Difference Bar Plot (Migraine - Control) with SEM Error Bars & No Connecting Lines
if options.barPlot && ~options.superSubj
    condMap = [1, 1; 2, 1; 1, 2; 2, 2]; % [contrastIdx, lightIdx]
    nConditions = size(condMap, 1);

    diffSigmaTest = zeros(1, nConditions);
    diffSigmaRef  = zeros(1, nConditions);
    errDiffTest   = zeros(1, nConditions);
    errDiffRef    = zeros(1, nConditions);

    for c = 1:nConditions
        cIdx = condMap(c, 1);
        lIdx = condMap(c, 2);
        
        valsCtrlTest = squeeze(mean(sigmaTestC(:, cIdx, lIdx, :), 4));
        valsMigTest  = squeeze(mean(sigmaTestM(:, cIdx, lIdx, :), 4));
        valsCtrlRef  = squeeze(mean(sigmaRefC(:, cIdx, lIdx, :), 4));
        valsMigRef   = squeeze(mean(sigmaRefM(:, cIdx, lIdx, :), 4));
        
        diffSigmaTest(c) = mean(valsMigTest) - mean(valsCtrlTest);
        diffSigmaRef(c)  = mean(valsMigRef)  - mean(valsCtrlRef);
        
        semCtrlTest = std(valsCtrlTest) / sqrt(nSubjC);
        semMigTest  = std(valsMigTest)  / sqrt(nSubjM);
        errDiffTest(c) = sqrt(semMigTest^2 + semCtrlTest^2);
        
        semCtrlRef  = std(valsCtrlRef)  / sqrt(nSubjC);
        semMigRef   = std(valsMigRef)   / sqrt(nSubjM);
        errDiffRef(c)  = sqrt(semMigRef^2 + semCtrlRef^2);
    end

    figBarDiff = figure('Color', 'w', 'Position', [150, 150, 950, 520], 'Name', 'Group Differences in Sigma (Migraine - Control)');
    ax = gca; hold(ax, 'on');

    % Gray background patch behind low-light conditions (Conditions 1 and 2: x = 0.5 to 2.5)
    patch(ax, [0.5 2.5 2.5 0.5], [-0.6 -0.6 0.6 0.6], ...
        [0.92 0.92 0.92], 'EdgeColor', 'none', 'FaceAlpha', 0.6);
    uistack(ax.Children(end), 'bottom'); 

    % Grouped bar plot: 4 conditions x 2 parameters ([SigmaTest, SigmaRef])
    barData = [diffSigmaTest(:), diffSigmaRef(:)];
    errData = [errDiffTest(:), errDiffRef(:)];
    b = bar(ax, barData, 'grouped', 'BarWidth', 0.7);
    b(1).FaceColor = [0.2 0.5 0.8]; % Sigma Test
    b(2).FaceColor = [0.8 0.4 0.2]; % Sigma Ref

    % Add SEM error bars
    for i = 1:numel(b)
        errorbar(ax, b(i).XEndPoints, b(i).YData, errData(:, i), ...
            'k', 'LineStyle', 'none', 'LineWidth', 2.0, 'CapSize', 6);
    end

    set(ax, 'XTick', 1:4, 'XTickLabel', {'Low Contrast', 'High Contrast', 'Low Contrast', 'High Contrast'}, 'FontSize', 11, 'LineWidth', 1.2);
    ylabel('\Delta \sigma (Migraine - Control)', 'FontSize', 14, 'FontWeight', 'bold');
    xlim([0.4 4.6]);
    ylim([-0.6 0.6]);
    box(ax, 'off'); grid(ax, 'off');
    
    legend([b(1), b(2)], {'$\sigma_{test}$', '$\sigma_{ref}$'}, 'Interpreter', 'latex', ...
        'Location', 'northeast', 'Box', 'off', 'FontSize', 13);
    title('Group Differences in Sigma Parameters', 'FontSize', 15, 'FontWeight', 'bold');
end

%% Grand Average Bar Plot (Pooled 30 Participants across Conditions)
if options.barPlot && ~options.superSubj
    condMap = [1, 1; 2, 1; 1, 2; 2, 2]; % [contrastIdx, lightIdx]
    nConditions = size(condMap, 1);

    grandMeanTest = zeros(1, nConditions);
    grandMeanRef  = zeros(1, nConditions);
    grandSEMTest  = zeros(1, nConditions);
    grandSEMRef   = zeros(1, nConditions);

    sigmaTestCombined = cat(1, sigmaTestM, sigmaTestC);
    sigmaRefCombined  = cat(1, sigmaRefM, sigmaRefC);
    nTotalSubj = size(sigmaTestCombined, 1);

    for c = 1:nConditions
        cIdx = condMap(c, 1);
        lIdx = condMap(c, 2);
        
        valsAllTest = squeeze(mean(sigmaTestCombined(:, cIdx, lIdx, :), 4));
        valsAllRef  = squeeze(mean(sigmaRefCombined(:, cIdx, lIdx, :), 4));
        
        grandMeanTest(c) = mean(valsAllTest);
        grandSEMTest(c)  = std(valsAllTest) / sqrt(nTotalSubj);
        
        grandMeanRef(c)  = mean(valsAllRef);
        grandSEMRef(c)   = std(valsAllRef) / sqrt(nTotalSubj);
    end

    figGrandAvg = figure('Color', 'w', 'Position', [200, 200, 950, 520], 'Name', 'Grand Average Sigma (All 30 Participants)');
    ax = gca; hold(ax, 'on');

    patch(ax, [0.5 2.5 2.5 0.5], [0 0 4 4], ...
        [0.92 0.92 0.92], 'EdgeColor', 'none', 'FaceAlpha', 0.6);
    uistack(ax.Children(end), 'bottom'); 

    grandBarData = [grandMeanTest(:), grandMeanRef(:)];
    grandErrData = [grandSEMTest(:), grandSEMRef(:)];
    bG = bar(ax, grandBarData, 'grouped', 'BarWidth', 0.7);
    bG(1).FaceColor = [0.2 0.5 0.8]; % Sigma Test
    bG(2).FaceColor = [0.8 0.4 0.2]; % Sigma Ref

    for i = 1:numel(bG)
        errorbar(ax, bG(i).XEndPoints, bG(i).YData, grandErrData(:, i), ...
            'k', 'LineStyle', 'none', 'LineWidth', 2.0, 'CapSize', 6);
    end

    set(ax, 'XTick', 1:4, 'XTickLabel', {'Low Contrast', 'High Contrast', 'Low Contrast', 'High Contrast'}, 'FontSize', 11, 'LineWidth', 1.2);
    ylabel('\sigma (Grand Average, N=30)', 'FontSize', 14, 'FontWeight', 'bold');
    xlim([0.4 4.6]);
    ylim([0 3.5]);
    box(ax, 'off'); grid(ax, 'off');
    
    legend([bG(1), bG(2)], {'$\sigma_{test}$', '$\sigma_{ref}$'}, 'Interpreter', 'latex', ...
        'Location', 'northeast', 'Box', 'off', 'FontSize', 13);
    title('Grand Average Sigma Across Conditions (N=30)', 'FontSize', 15, 'FontWeight', 'bold');
end

%% Quality Control Histograms (fVal)
if options.fVal
    fValsMigraine = migraineFits.fValMatrix(:);
    fValsControl  = controlFits.fValMatrix(:);
    
    allData = [fValsMigraine; fValsControl];
    edges = linspace(min(allData), max(allData), 20);
    
    figure('Color', 'w'); hold on;
    histogram(fValsMigraine, edges, ...
        'FaceColor', colMigraineHigh, ...
        'FaceAlpha', 0.65, ...
        'EdgeColor', colMigraineHigh * 0.7, ...
        'LineWidth', 1.2);
        
    histogram(fValsControl, edges, ...
        'FaceColor', colControlHigh, ...
        'FaceAlpha', 0.65, ...
        'EdgeColor', colControlHigh * 0.7, ...
        'LineWidth', 1.2);
        
    xlabel('Negative log-likelihood (fVal)');
    ylabel('Count');
    legend({'Migrainers', 'Controls'}, 'Box', 'off', 'Location', 'northeast');
    title('Model fit quality across groups');
    box off; grid off;
    
    figFVal = figure('Color', 'w', 'Name', 'Fit Quality Across Conditions');
    figFVal.Units = 'pixels';
    figFVal.Position = [100 100 900 900];
    
    yMaxFVal = 55;
    
    panelIdx = 1;
    for l = 1:2 
        for c = 1:2 
            subplot(2, 2, panelIdx);
            ax = gca; set(ax, 'FontSize', 14, 'FontName', 'Helvetica'); hold on;
            
            mMeanfVal = squeeze(mean(migraineFits.fValMatrix(:,c,l,:), 1));
            mSEMfVal  = squeeze(std(migraineFits.fValMatrix(:,c,l,:), [], 1)) / sqrt(nSubjM);
            cMeanfVal = squeeze(mean(controlFits.fValMatrix(:,c,l,:), 1));
            cSEMfVal  = squeeze(std(controlFits.fValMatrix(:,c,l,:), [], 1)) / sqrt(nSubjC);
            
            errorbar(refFreqHz, mMeanfVal, mSEMfVal, '-o', 'Color', colMigraineHigh, ...
                'MarkerFaceColor', colMigraineHigh, 'LineWidth', 1.8, 'MarkerSize', 11);
            errorbar(refFreqHz, cMeanfVal, cSEMfVal, '-s', 'Color', colControlHigh, ...
                'MarkerFaceColor', colControlHigh, 'LineWidth', 1.8, 'MarkerSize', 11);
            
            ylim([0 yMaxFVal]);
            xlim([min(refFreqHz)*0.9, max(refFreqHz)*1.1]);
            
            if l == 1
                xl = [min(refFreqHz)*0.85, max(refFreqHz)*1.15];
                p = patch([xl(1) xl(2) xl(2) xl(1)], [0 0 yMaxFVal yMaxFVal], ...
                    [0.92 0.92 0.92], 'EdgeColor', 'none', 'FaceAlpha', 0.5);
                uistack(p, 'bottom');
            end
            
            xlabel('Reference Frequency (Hz)');
            ylabel('Negative log-likelihood (fVal)');
            title(sprintf('%s | %s', lightLabels{l}, contrastLabels{c}));
            xticks([10 13 17 23 30]);
            axis square;
            box off; grid off;
            set(ax, 'XScale', 'log');
            
            if panelIdx == 1
                hL_M = plot(NaN, NaN, '-o', 'Color', colMigraineHigh, ...
                    'MarkerFaceColor', colMigraineHigh, 'LineWidth', 1.8, 'MarkerSize', 11);
                hL_C = plot(NaN, NaN, '-s', 'Color', colControlHigh, ...
                    'MarkerFaceColor', colControlHigh, 'LineWidth', 1.8, 'MarkerSize', 11);
                
                lgd = legend([hL_M, hL_C], {'Migraine', 'Control'}, ...
                    'Location', 'northeast', 'Box', 'off');
                lgd.ItemTokenSize = [30, 18];
            end
            
            panelIdx = panelIdx + 1;
        end
    end
end

%% Omnibus ANOVAS & FDR-Corrected Follow-Up t-Tests
if options.anova
    sigmaTestAll = cat(1, sigmaTestM, sigmaTestC);
    sigmaRefAll  = cat(1, sigmaRefM, sigmaRefC);
    [nS, nC, nL, nF] = size(sigmaTestAll);
    [S_idx, C_idx, L_idx, F_idx] = ndgrid(1:nS, 1:nC, 1:nL, 1:nF);
    nMigraine = size(sigmaTestM, 1);
    G_idx = ones(nS, nC, nL, nF);
    G_idx((nMigraine+1):end, :, :, :) = 2;
    nest = zeros(5, 5);
    nest(1, 2) = 1;
    factors = {S_idx(:), G_idx(:), C_idx(:), L_idx(:), F_idx(:)};
    varnames = {'Subject', 'Group', 'Contrast', 'LightLevel', 'Frequency'};
    
    [~, tblTest, ~] = anovan(sigmaTestAll(:), factors, ...
        'nested', nest, 'random', 1, 'model', 3, 'varnames', varnames, 'display', 'off');
        
    [~, tblRef, ~] = anovan(sigmaRefAll(:), factors, ...
        'nested', nest, 'random', 1, 'model', 3, 'varnames', varnames, 'display', 'off');
        
    % Print ANOVA tables with FDR correction to console (bolding raw significant, star on FDR)
    output.tblTest = printAndCorrectAnova(tblTest, 'Sigma Test');
    output.tblRef  = printAndCorrectAnova(tblRef,  'Sigma Ref');
        
    % Run group follow-up t-tests for terms involving Group where raw p < 0.05
    output.tTestsTest = runGroupThreeWayFollowUps(tblTest, sigmaTestAll, G_idx, C_idx, L_idx, F_idx, refFreqHz, 'Sigma Test');
    output.tTestsRef  = runGroupThreeWayFollowUps(tblRef,  sigmaRefAll,  G_idx, C_idx, L_idx, F_idx, refFreqHz, 'Sigma Ref');
        
    testM = sigmaTestM(:);
    testC = sigmaTestC(:);
    refM  = sigmaRefM(:);
    refC  = sigmaRefC(:);
    
    allTest = [testM; testC];
    testEdges = linspace(min(allTest), max(allTest), 40);
    
    figure;
    nexttile; hold on;
    set(gca,'FontSize',30);
    set(gca,'TickLabelInterpreter','latex');
    histogram(testM, testEdges, 'FaceColor', colMigraineHigh, 'FaceAlpha', 0.4, 'EdgeColor', 'none');
    histogram(testC, testEdges, 'FaceColor', colControlHigh, 'FaceAlpha', 0.4, 'EdgeColor', 'none');
    xlabel('$\sigma$ value', 'Interpreter', 'latex');  ylabel('');
    xticks([0 1 2 3 4 5]);
    yticks([0 10 20 30 40]);
    legend({'Migraine', 'Control'}, 'Box', 'off', 'Interpreter', 'latex');
    box off; grid off;
end
end

%% Helper function for Benjamini-Hochberg FDR correction
function pFDR = benjaminiHochberg(pVals)
    pVals = pVals(:);
    [pSorted, sortIdx] = sort(pVals);
    n = numel(pSorted);
    pFDR_sorted = pSorted .* n ./ (1:n)';
    for i = n-1:-1:1
        pFDR_sorted(i) = min(pFDR_sorted(i), pFDR_sorted(i+1));
    end
    pFDR = zeros(size(pVals));
    pFDR(sortIdx) = min(1, pFDR_sorted);
end

%% Helper function to print ANOVA tables to console using FDR
function tblOut = printAndCorrectAnova(tbl, paramName)
    if iscell(tbl)
        rawSource = tbl(2:end-1, 1);
        rawF      = cell2mat(tbl(2:end-1, 6));
        rawP      = cell2mat(tbl(2:end-1, 7));
    else
        rawSource = tbl.Properties.RowNames;
        rawF      = tbl.F;
        rawP      = tbl.('Prob>F');
    end
    
    validIdx = true(size(rawP));
    for i = 1:length(rawP)
        if isnan(rawP(i)) || isempty(rawSource{i}) || ...
           contains(lower(string(rawSource{i})), 'error') || ...
           contains(lower(string(rawSource{i})), 'total')
            validIdx(i) = false;
        end
    end
    
    sourceCol = string(rawSource(validIdx));
    fCol      = rawF(validIdx);
    pvalCol   = rawP(validIdx);
    
    sourceCol = sourceCol(:);
    fCol      = fCol(:);
    pvalCol   = pvalCol(:);
    
    pFDR      = benjaminiHochberg(pvalCol);
    pFDR      = pFDR(:);
    
    fprintf('\n========================================================================================\n');
    fprintf('                          ANOVA RESULTS TABLE (FDR): %s\n', upper(paramName));
    fprintf('========================================================================================\n');
    fprintf('%-35s | %-10s | %-12s | %-14s\n', 'Source / Interaction Term', 'F-Value', 'Raw p-Value', 'FDR p-Value');
    fprintf('----------------------------------------------------------------------------------------\n');
    
    for i = 1:length(pvalCol)
        termName = sourceCol(i);
        fVal = fCol(i);
        pRaw = pvalCol(i);
        pAdj = pFDR(i);
        
        starStr = if_then(pAdj < 0.05, ' *', '');
        
        % Bold if raw p < 0.05
        if pRaw < 0.05
            strTerm = sprintf('\x1B[1m%-35s\x1B[0m', termName);
            strF    = sprintf('\x1B[1m%10.3f\x1B[0m', fVal);
            strRaw  = sprintf('\x1B[1m%12.4e\x1B[0m', pRaw);
            strAdj  = sprintf('\x1B[1m%14.4e%s\x1B[0m', pAdj, starStr);
        else
            strTerm = sprintf('%-35s', termName);
            strF    = sprintf('%10.3f', fVal);
            strRaw  = sprintf('%12.4e', pRaw);
            strAdj  = sprintf('%14.4e%s', pAdj, starStr);
        end
        
        fprintf('%s | %s | %s | %s\n', strTerm, strF, strRaw, strAdj);
    end
    fprintf('========================================================================================\n');
    
    tblOut = table(sourceCol, fCol, pvalCol, pFDR, 'VariableNames', {'Term', 'F_Value', 'p_Raw', 'p_FDR'});
end

%% Helper function to compute, print, and return group t-test results table with FDR correction
function tTestTable = runGroupThreeWayFollowUps(tbl, dataAll, G_idx, C_idx, L_idx, F_idx, refFreqHz, paramName)
    interaction_col = {};
    factor1_col = {};
    factor2_col = {};
    tstat_col = [];
    raw_p_col = [];
    
    if iscell(tbl)
        rawSource = tbl(2:end-1, 1);
        rawP      = cell2mat(tbl(2:end-1, 7));
    else
        rawSource = tbl.Properties.RowNames;
        rawP      = tbl.('Prob>F');
    end
    
    validIdx = true(size(rawP));
    for i = 1:length(rawP)
        if isnan(rawP(i)) || isempty(rawSource{i}) || ...
           contains(lower(string(rawSource{i})), 'error') || ...
           contains(lower(string(rawSource{i})), 'total')
            validIdx(i) = false;
        end
    end
    
    sourceCol = string(rawSource(validIdx));
    pvalCol   = rawP(validIdx);
    
    factorMap = containers.Map({'Contrast', 'LightLevel', 'Frequency'}, {C_idx, L_idx, F_idx});
    
    for i = 1:length(pvalCol)
        termName = sourceCol(i);
        pVal = pvalCol(i);
        
        % Skip non-group terms or subject nesting
        if ~contains(termName, 'Group') || contains(termName, 'Subject')
            continue;
        end
        
        % Check if raw ANOVA p-value is significant (< 0.05)
        if pVal < 0.05
            if contains(termName, ':')
                parts = split(termName, ':');
            else
                parts = split(termName, '*');
            end
            
            otherFactors = setdiff(parts, 'Group');
            
            if isempty(otherFactors)
                % Main effect of Group
                group1Data = dataAll(G_idx == 1);
                group2Data = dataAll(G_idx == 2);
                [~, pRaw, ~, stats] = ttest2(group1Data, group2Data);
                
                interaction_col{end+1, 1} = char(termName);
                factor1_col{end+1, 1}     = 'All Conditions';
                factor2_col{end+1, 1}     = 'N/A';
                tstat_col(end+1, 1)       = stats.tstat;
                raw_p_col(end+1, 1)       = pRaw;
            elseif numel(otherFactors) == 1
                % 2-way interaction involving Group
                f1Vals = unique(factorMap(char(otherFactors(1))));
                
                for f1 = f1Vals'
                    mask1 = (factorMap(char(otherFactors(1))) == f1) & (G_idx == 1);
                    mask2 = (factorMap(char(otherFactors(1))) == f1) & (G_idx == 2);
                    
                    group1Data = dataAll(mask1);
                    group2Data = dataAll(mask2);
                    
                    [~, pRaw, ~, stats] = ttest2(group1Data, group2Data);
                    
                    interaction_col{end+1, 1} = char(termName);
                    factor1_col{end+1, 1}     = getFactorTextLabel(char(otherFactors(1)), f1, refFreqHz);
                    factor2_col{end+1, 1}     = 'N/A';
                    tstat_col(end+1, 1)       = stats.tstat;
                    raw_p_col(end+1, 1)       = pRaw;
                end
            else
                % 3-way interaction involving Group
                f1Vals = unique(factorMap(char(otherFactors(1))));
                f2Vals = unique(factorMap(char(otherFactors(2))));
                
                for f1 = f1Vals'
                    for f2 = f2Vals'
                        mask1 = (factorMap(char(otherFactors(1))) == f1) & (factorMap(char(otherFactors(2))) == f2) & (G_idx == 1);
                        mask2 = (factorMap(char(otherFactors(1))) == f1) & (factorMap(char(otherFactors(2))) == f2) & (G_idx == 2);
                        
                        group1Data = dataAll(mask1);
                        group2Data = dataAll(mask2);
                        
                        [~, pRaw, ~, stats] = ttest2(group1Data, group2Data);
                        
                        interaction_col{end+1, 1} = char(termName);
                        factor1_col{end+1, 1}     = getFactorTextLabel(char(otherFactors(1)), f1, refFreqHz);
                        factor2_col{end+1, 1}     = getFactorTextLabel(char(otherFactors(2)), f2, refFreqHz);
                        tstat_col(end+1, 1)       = stats.tstat;
                        raw_p_col(end+1, 1)       = pRaw;
                    end
                end
            end
        end
    end
    
    if ~isempty(interaction_col)
        fdr_p_col = benjaminiHochberg(raw_p_col);
        
        tTestTable = table(string(interaction_col), string(factor1_col), string(factor2_col), tstat_col, raw_p_col, fdr_p_col, ...
            'VariableNames', {'Interaction', 'Factor1', 'Factor2', 't_Stat', 'p_Raw', 'p_FDR'});
        
        fprintf('\n========================================================================================\n');
        fprintf('             GROUP FOLLOW-UP T-TESTS TABLE (FDR Corrected): %s\n', upper(paramName));
        fprintf('========================================================================================\n');
        fprintf('%-28s | %-16s | %-16s | %-10s | %-12s | %-14s\n', 'Interaction Term', 'Factor 1', 'Factor 2', 't-Stat', 'Raw p-Value', 'FDR p-Value');
        fprintf('----------------------------------------------------------------------------------------\n');
        
        for r = 1:height(tTestTable)
            termStr = tTestTable.Interaction(r);
            f1Str   = tTestTable.Factor1(r);
            f2Str   = tTestTable.Factor2(r);
            tVal    = tTestTable.t_Stat(r);
            pRaw    = tTestTable.p_Raw(r);
            pAdj    = tTestTable.p_FDR(r);
            
            starStr = if_then(pAdj < 0.05, ' *', '');
            
            % Bold if raw p < 0.05
            if pRaw < 0.05
                fprintf('\x1B[1m%-28s | %-16s | %-16s | %10.3f | %12.4e | %14.4e%s\x1B[0m\n', ...
                    termStr, f1Str, f2Str, tVal, pRaw, pAdj, starStr);
            else
                fprintf('%-28s | %-16s | %-16s | %10.3f | %12.4e | %14.4e%s\n', ...
                    termStr, f1Str, f2Str, tVal, pRaw, pAdj, starStr);
            end
        end
        fprintf('========================================================================================\n');
    else
        tTestTable = table(string.empty(0,1), string.empty(0,1), string.empty(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
            'VariableNames', {'Interaction', 'Factor1', 'Factor2', 't_Stat', 'p_Raw', 'p_FDR'});
            
        fprintf('\n========================================================================================\n');
        fprintf('             GROUP FOLLOW-UP T-TESTS TABLE (FDR Corrected): %s\n', upper(paramName));
        fprintf('========================================================================================\n');
        fprintf('No terms involving Group reached raw ANOVA significance (p < 0.05).\n');
        fprintf('========================================================================================\n');
    end
end

%% Helper function to translate factor index numbers into readable string labels
function labelStr = getFactorTextLabel(factorName, idxVal, refFreqHz)
    switch factorName
        case 'Contrast'
            contrastLabels = {'Low Contrast', 'High Contrast'};
            labelStr = contrastLabels{idxVal};
        case 'LightLevel'
            lightLabels = {'Low Light', 'High Light'};
            labelStr = lightLabels{idxVal};
        case 'Frequency'
            labelStr = sprintf('%d Hz', refFreqHz(idxVal));
        otherwise
            labelStr = sprintf('%s=%d', factorName, idxVal);
    end
end

% Helper function for title logic
function out = if_then(cond, a, b)
if cond, out = a; else, out = b; end
end