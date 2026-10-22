function output = individualFitsAnalysis(options)
%Performs statistical analysis and visualization of
% sigma fit parameters (sigmaTest and sigmaRef) from dichoptic flicker experiments.
%
%   OUTPUT = INDIVIDUALFITSANALYSIS(OPTIONS) loads model fit parameters across 
%   experimental conditions (Contrasts x Light Levels x Frequencies) for Migraine 
%   and Control groups (or super-subjects), generates comparative figures, conducts
%   omnibus ANOVAs, and returns statistical tables and summary metrics in OUTPUT.
%
%   INPUT OPTIONS (Name-Value Pairs):
%     barPlot      - (Logical) Generate bar charts comparing sigma values across
%                    contrast/light conditions and group difference interactions.
%                    Default: true
%     beeSwarm     - (Logical) Overlay individual subject datapoints on bar/summary
%                    plots. Default: true
%     fVal         - (Logical) Plot negative log-likelihood (fit quality) distributions
%                    and condition-wise comparisons. Default: true
%     anova        - (Logical) Run 5-way nested mixed-effects ANOVAs (Subject nested
%                    in Group) for both sigmaTest and sigmaRef. Default: true
%     superSubj    - (Logical) Flag to load pooled "super-subject" data instead
%                    of individual subject fit files. Default: false
%     effectOfFreq - (Logical) Plot main effect of reference frequency on sigma
%                    parameters. Default: true
%     sigmaTest    - (Logical) Flag to control bar plot focus. Default: true

arguments
    options.barPlot (1,1) logical = true
    options.beeSwarm (1,1) logical = true
    options.fVal (1,1) logical = true
    options.anova (1,1) logical = true
    options.superSubj (1,1) logical = false
    options.effectOfFreq (1,1) logical = true
    options.sigmaTest (1,1) logical = true
end

%% Load Data
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
    nSubjC = 1; nSubjM = 1;
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

%% Global Color Palette Definitions
colMigraineHigh = [0.72 0.22 0.48];
colMigraineLow  = [0.88 0.55 0.72];
colControlHigh  = [0.18 0.48 0.62];
colControlLow   = [0.55 0.76 0.85];

%% Calculate Means and SEMs
muSigmaTestC  = squeeze(mean(mean(sigmaTestC,  4),1));
muSigmaTestM   = squeeze(mean(mean(sigmaTestM,  4),1));
semSigmaTestC = squeeze(std(mean(sigmaTestC,  4),  [], 1) ./ sqrt(nSubjC));
semSigmaTestM  = squeeze(std(mean(sigmaTestM,  4), [], 1) ./ sqrt(nSubjM));

muSigmaRefC  = squeeze(mean(mean(sigmaRefC,  4),1));
muSigmaRefM   = squeeze(mean(mean(sigmaRefM,  4),1));
semSigmaRefC = squeeze(std(mean(sigmaRefC,  4),  [], 1) ./ sqrt(nSubjC));
semSigmaRefM  = squeeze(std(mean(sigmaRefM,  4), [], 1) ./ sqrt(nSubjM));

%% Populate Initial Output Data
output = struct();
output.data.sigmaTestC = sigmaTestC;
output.data.sigmaTestM = sigmaTestM;
output.data.sigmaRefC  = sigmaRefC;
output.data.sigmaRefM  = sigmaRefM;
output.data.refFreqHz  = refFreqHz;

%% 2x2 Grid Plot: Sigma Test
figTest = figure('Color', 'w', 'Name', 'Sigma Test Across Conditions');
figTest.Units = 'pixels'; figTest.Position = [100 100 900 900];

panelIdx = 1;
for l = 1:2
    for c = 1:2
        subplot(2, 2, panelIdx);
        ax = gca; set(ax, 'FontSize', 14, 'FontName', 'Helvetica'); hold on;
        
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
        ylim([0 4]); xlim([min(refFreqHz)*0.9, max(refFreqHz)*1.1]);
        xticks([10 13 17 23 30]); yticks(0:4);
        axis square; box off; grid off; set(ax, 'XScale', 'log');
        
        if panelIdx == 1
            hL_M = plot(NaN, NaN, '-o', 'Color', colMigraineHigh, 'MarkerFaceColor', colMigraineHigh, 'LineWidth', 1.8, 'MarkerSize', 11);
            hL_C = plot(NaN, NaN, '-s', 'Color', colControlHigh, 'MarkerFaceColor', colControlHigh, 'LineWidth', 1.8, 'MarkerSize', 11);
            lgd = legend([hL_M, hL_C], {'Migraine', 'Control'}, 'Location', 'northwest', 'Box', 'off');
            lgd.ItemTokenSize = [30, 18];
        end
        panelIdx = panelIdx + 1;
    end
end

%% 2x2 Grid Plot: Sigma Ref
figRef = figure('Color', 'w', 'Name', 'Sigma Ref Across Conditions');
figRef.Units = 'pixels'; figRef.Position = [100 100 900 900];

panelIdx = 1;
for l = 1:2
    for c = 1:2
        subplot(2, 2, panelIdx);
        ax = gca; set(ax, 'FontSize', 14, 'FontName', 'Helvetica'); hold on;
        
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
            p = patch([xl(1) xl(2) xl(2) xl(1)], [0 0 2 2], ...
                [0.92 0.92 0.92], 'EdgeColor', 'none', 'FaceAlpha', 0.5);
            uistack(p, 'bottom');
        end
        
        xlabel('Reference Frequency (Hz)');
        ylabel('$\sigma_{ref}$', 'Interpreter', 'latex', 'FontSize', 18);
        title(sprintf('%s | %s', lightLabels{l}, contrastLabels{c}));
        ylim([0 2]); xlim([min(refFreqHz)*0.9, max(refFreqHz)*1.1]);
        xticks([10 13 17 23 30]); yticks(0:0.5:2);
        axis square; box off; grid off; set(ax, 'XScale', 'log');
        
        if panelIdx == 1
            hL_M = plot(NaN, NaN, '-o', 'Color', colMigraineHigh, 'MarkerFaceColor', colMigraineHigh, 'LineWidth', 1.8, 'MarkerSize', 11);
            hL_C = plot(NaN, NaN, '-s', 'Color', colControlHigh, 'MarkerFaceColor', colControlHigh, 'LineWidth', 1.8, 'MarkerSize', 11);
            lgd = legend([hL_M, hL_C], {'Migraine', 'Control'}, 'Location', 'northeast', 'Box', 'off');
            lgd.ItemTokenSize = [30, 18];
        end
        panelIdx = panelIdx + 1;
    end
end

%% Bee Swarm Plots Across Conditions (Light x Contrast)
if options.beeSwarm && ~options.superSubj
    % Sigma Test Bee Swarm
    figure('Color','w','Name','Bee Swarm: Sigma Test');
    figurePosition = [100 100 900 900]; set(gcf, 'Units', 'pixels', 'Position', figurePosition);
    panelIdx = 1;
    for l = 1:2
        for c = 1:2
            subplot(2,2,panelIdx); hold on; set(gca,'FontSize',14,'FontName','Helvetica');
            
            cVals = squeeze(mean(sigmaTestC(:,c,l,:), 4));
            mVals = squeeze(mean(sigmaTestM(:,c,l,:), 4));
            
            swarmchart(repmat(1, size(cVals)), cVals, 50, ...
                'MarkerFaceColor', colControlHigh, 'MarkerEdgeColor', colControlHigh * 0.7, ...
                'MarkerFaceAlpha', 0.7, 'XJitter', 'density', 'XJitterWidth', 0.25);
            swarmchart(repmat(2, size(mVals)), mVals, 50, ...
                'MarkerFaceColor', colMigraineHigh, 'MarkerEdgeColor', colMigraineHigh * 0.7, ...
                'MarkerFaceAlpha', 0.7, 'XJitter', 'density', 'XJitterWidth', 0.25);
            
            errorbar(1, mean(cVals), std(cVals)/sqrt(length(cVals)), 'k_', 'LineWidth', 2.5, 'MarkerSize', 15);
            errorbar(2, mean(mVals), std(mVals)/sqrt(length(mVals)), 'k_', 'LineWidth', 2.5, 'MarkerSize', 15);
            
            xlim([0.5 2.5]); ylim([0 4]); xticks([1 2]); xticklabels({'Control', 'Migraine'});
            ylabel('$\sigma_{test}$', 'Interpreter', 'latex', 'FontSize', 18);
            title(sprintf('%s | %s', lightLabels{l}, contrastLabels{c}));
            axis square; box off; grid off;
            panelIdx = panelIdx + 1;
        end
    end
    
    % Sigma Ref Bee Swarm
    figure('Color','w','Name','Bee Swarm: Sigma Ref');
    set(gcf, 'Units', 'pixels', 'Position', figurePosition);
    panelIdx = 1;
    for l = 1:2
        for c = 1:2
            subplot(2,2,panelIdx); hold on; set(gca,'FontSize',14,'FontName','Helvetica');
            
            cVals = squeeze(mean(sigmaRefC(:,c,l,:), 4));
            mVals = squeeze(mean(sigmaRefM(:,c,l,:), 4));
            
            swarmchart(repmat(1, size(cVals)), cVals, 50, ...
                'MarkerFaceColor', colControlHigh, 'MarkerEdgeColor', colControlHigh * 0.7, ...
                'MarkerFaceAlpha', 0.7, 'XJitter', 'density', 'XJitterWidth', 0.25);
            swarmchart(repmat(2, size(mVals)), mVals, 50, ...
                'MarkerFaceColor', colMigraineHigh, 'MarkerEdgeColor', colMigraineHigh * 0.7, ...
                'MarkerFaceAlpha', 0.7, 'XJitter', 'density', 'XJitterWidth', 0.25);
            
            errorbar(1, mean(cVals), std(cVals)/sqrt(length(cVals)), 'k_', 'LineWidth', 2.5, 'MarkerSize', 15);
            errorbar(2, mean(mVals), std(mVals)/sqrt(length(mVals)), 'k_', 'LineWidth', 2.5, 'MarkerSize', 15);
            
            xlim([0.5 2.5]); ylim([0 2]); xticks([1 2]); xticklabels({'Control', 'Migraine'});
            ylabel('$\sigma_{ref}$', 'Interpreter', 'latex', 'FontSize', 18);
            title(sprintf('%s | %s', lightLabels{l}, contrastLabels{c}));
            axis square; box off; grid off;
            panelIdx = panelIdx + 1;
        end
    end
end

%% Poster Plots: Combined Frequency Effects
if options.effectOfFreq
    lightLevel = 2; contrastLevel = 2;
    
    % Poster Plot: Sigma Test
    mDataTest = squeeze(sigmaTestM(:,contrastLevel,lightLevel,:));
    cDataTest = squeeze(sigmaTestC(:,contrastLevel,lightLevel,:));
    allTest = [mDataTest; cDataTest];
    muTest = mean(allTest,1); semTest = std(allTest,[],1) ./ sqrt(size(allTest,1));
    
    fig = figure('Color','w','Name','Poster: Sigma Test');
    fig.Units = 'pixels'; fig.Position = [100 100 1400 450]; set(fig,'InvertHardcopy','off');
    ax = gca; ax.FontName = 'Helvetica'; ax.FontSize = 35; ax.LineWidth = 1.5; hold on;
    
    if options.beeSwarm && ~options.superSubj
        nTotalSubj = size(allTest, 1); jitterWidth = 0.04;
        for fIdx = 1:length(refFreqHz)
            fVal = refFreqHz(fIdx); yVals = allTest(:, fIdx);
            xJittered = fVal .* (1 + (rand(nTotalSubj, 1) - 0.5) * jitterWidth);
            scatter(xJittered, yVals, 65, 'MarkerFaceColor', [0.35 0.35 0.35], ...
                'MarkerEdgeColor', 'none', 'MarkerFaceAlpha', 0.35);
        end
    end
    h1 = errorbar(refFreqHz, muTest, semTest, '-', 'Color', 'k', 'LineWidth', 2.5, 'CapSize', 12, ...
        'Marker', 'o', 'MarkerSize', 22, 'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'w');
    uistack(h1,'top');
    xlabel('Reference Frequency (Hz)', 'FontSize',35);
    ylabel('$\sigma_{test}$', 'Interpreter', 'latex', 'FontSize',45);
    xlim([min(refFreqHz)*0.9, max(refFreqHz)*1.1]); ylim([0 4]); set(gca,'XScale','log');
    grid off; box off; xticks([10 13 17 23 30]);
    
    % Poster Plot: Sigma Ref
    mDataRef = squeeze(sigmaRefM(:,contrastLevel,lightLevel,:));
    cDataRef = squeeze(sigmaRefC(:,contrastLevel,lightLevel,:));
    allRef = [mDataRef; cDataRef];
    muRef = mean(allRef,1); semRef = std(allRef,[],1) ./ sqrt(size(allRef,1));
    
    figR = figure('Color','w','Name','Poster: Sigma Ref');
    figR.Units = 'pixels'; figR.Position = [100 100 1400 450]; set(figR,'InvertHardcopy','off');
    ax = gca; ax.FontName = 'Helvetica'; ax.FontSize = 35; ax.LineWidth = 1.5; hold on;
    
    if options.beeSwarm && ~options.superSubj
        nTotalSubj = size(allRef, 1); jitterWidth = 0.04;
        for fIdx = 1:length(refFreqHz)
            fVal = refFreqHz(fIdx); yVals = allRef(:, fIdx);
            xJittered = fVal .* (1 + (rand(nTotalSubj, 1) - 0.5) * jitterWidth);
            scatter(xJittered, yVals, 65, 'MarkerFaceColor', [0.35 0.35 0.35], ...
                'MarkerEdgeColor', 'none', 'MarkerFaceAlpha', 0.35);
        end
    end
    h2 = errorbar(refFreqHz, muRef, semRef, '-', 'Color', 'k', 'LineWidth', 2.5, 'CapSize', 12, ...
        'Marker', 's', 'MarkerSize', 22, 'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'w');
    uistack(h2,'top');
    xlabel('Reference Frequency (Hz)', 'FontSize',35);
    ylabel('$\sigma_{ref}$', 'Interpreter', 'latex', 'FontSize',45);
    xlim([min(refFreqHz)*0.9, max(refFreqHz)*1.1]); ylim([0 2]); set(gca,'XScale','log');
    grid off; box off; xticks([10 13 17 23 30]);
end

%% Delta Sigma Bar Plots (Organized by Contrast: Control vs Migraine)
if options.barPlot && ~options.superSubj
    mTestLight = squeeze(mean(sigmaTestM, 4));
    cTestLight = squeeze(mean(sigmaTestC, 4));
    
    % Delta = High Light - Low Light
    cDiffTest_LowC  = cTestLight(:, 1, 2) - cTestLight(:, 1, 1);
    mDiffTest_LowC  = mTestLight(:, 1, 2) - mTestLight(:, 1, 1);
    cDiffTest_HighC = cTestLight(:, 2, 2) - cTestLight(:, 2, 1);
    mDiffTest_HighC = mTestLight(:, 2, 2) - mTestLight(:, 2, 1);
    
    % Rows: Low Contrast, High Contrast | Columns: Control, Migraine
    deltaTestMeans = [mean(cDiffTest_LowC),  mean(mDiffTest_LowC); ...
                      mean(cDiffTest_HighC), mean(mDiffTest_HighC)];
    deltaTestSEMs  = [std(cDiffTest_LowC)/sqrt(nSubjC),  std(mDiffTest_LowC)/sqrt(nSubjM); ...
                      std(cDiffTest_HighC)/sqrt(nSubjC), std(mDiffTest_HighC)/sqrt(nSubjM)];
    
    % Narrower figure canvas
    figDeltaT = figure('Color','w','Name','Delta Sigma Test by Contrast');
    figDeltaT.Units = 'pixels'; figDeltaT.Position = [100 100 650 600];
    ax = gca; ax.FontName = 'Helvetica'; ax.FontSize = 26; ax.LineWidth = 1.5; hold on;
    
    bT = bar(deltaTestMeans, 'grouped', 'BarWidth', 0.7);
    bT(1).FaceColor = 'flat'; bT(2).FaceColor = 'flat';
    
    % Column 1: Control (Low & High Contrast), Column 2: Migraine (Low & High Contrast)
    bT(1).CData(1,:) = colControlLow;  bT(1).CData(2,:) = colControlHigh;
    bT(2).CData(1,:) = colMigraineLow; bT(2).CData(2,:) = colMigraineHigh;
    
    for i = 1:numel(bT)
        errorbar(bT(i).XEndPoints, bT(i).YData, deltaTestSEMs(:,i), 'k', 'LineStyle', 'none', 'LineWidth', 2.5);
    end
    
    if options.beeSwarm
        swarmchart(repmat(bT(1).XEndPoints(1), size(cDiffTest_LowC)), cDiffTest_LowC, 45, 'MarkerFaceColor', colControlLow*0.7, 'XJitter', 'density', 'XJitterWidth', 0.12);
        swarmchart(repmat(bT(2).XEndPoints(1), size(mDiffTest_LowC)), mDiffTest_LowC, 45, 'MarkerFaceColor', colMigraineLow*0.7, 'XJitter', 'density', 'XJitterWidth', 0.12);
        swarmchart(repmat(bT(1).XEndPoints(2), size(cDiffTest_HighC)), cDiffTest_HighC, 45, 'MarkerFaceColor', colControlHigh*0.7, 'XJitter', 'density', 'XJitterWidth', 0.12);
        swarmchart(repmat(bT(2).XEndPoints(2), size(mDiffTest_HighC)), mDiffTest_HighC, 45, 'MarkerFaceColor', colMigraineHigh*0.7, 'XJitter', 'density', 'XJitterWidth', 0.12);
    end
    
    set(gca, 'XTick', 1:2, 'XTickLabel', {'Low Contrast', 'High Contrast'});
    ylabel('$\Delta \sigma_{\mathrm{\it{test}}}$ (High - Low Light)', 'Interpreter', 'latex', 'FontSize', 30);
    
    % Custom Dummy Handles for Legend (Control vs Migraine)
    hLegControl  = patch(NaN, NaN, colControlHigh, 'EdgeColor', 'none');
    hLegMigraine = patch(NaN, NaN, colMigraineHigh, 'EdgeColor', 'none');
    lgd = legend([hLegControl, hLegMigraine], {'Control', 'Migraine'}, 'Location', 'northeast', 'Box', 'off');
    lgd.FontSize = 20; box off; xlim([0.4 2.6]);
    
    % Repeat for Delta Sigma Ref
    mRefLight = squeeze(mean(sigmaRefM, 4));
    cRefLight = squeeze(mean(sigmaRefC, 4));
    
    cDiffRef_LowC  = cRefLight(:, 1, 2) - cRefLight(:, 1, 1);
    mDiffRef_LowC  = mRefLight(:, 1, 2) - mRefLight(:, 1, 1);
    cDiffRef_HighC = cRefLight(:, 2, 2) - cRefLight(:, 2, 1);
    mDiffRef_HighC = mRefLight(:, 2, 2) - mRefLight(:, 2, 1);
    
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
        swarmchart(repmat(bR(1).XEndPoints(1), size(cDiffRef_LowC)), cDiffRef_LowC, 45, 'MarkerFaceColor', colControlLow*0.7, 'XJitter', 'density', 'XJitterWidth', 0.12);
        swarmchart(repmat(bR(2).XEndPoints(1), size(mDiffRef_LowC)), mDiffRef_LowC, 45, 'MarkerFaceColor', colMigraineLow*0.7, 'XJitter', 'density', 'XJitterWidth', 0.12);
        swarmchart(repmat(bR(1).XEndPoints(2), size(cDiffRef_HighC)), cDiffRef_HighC, 45, 'MarkerFaceColor', colControlHigh*0.7, 'XJitter', 'density', 'XJitterWidth', 0.12);
        swarmchart(repmat(bR(2).XEndPoints(2), size(mDiffRef_HighC)), mDiffRef_HighC, 45, 'MarkerFaceColor', colMigraineHigh*0.7, 'XJitter', 'density', 'XJitterWidth', 0.12);
    end
    
    set(gca, 'XTick', 1:2, 'XTickLabel', {'Low Contrast', 'High Contrast'});
    ylabel('$\Delta \sigma_{\mathrm{\it{ref}}}$ (High - Low Light)', 'Interpreter', 'latex', 'FontSize', 30);
    
    hLegControl  = patch(NaN, NaN, colControlHigh, 'EdgeColor', 'none');
    hLegMigraine = patch(NaN, NaN, colMigraineHigh, 'EdgeColor', 'none');
    lgd = legend([hLegControl, hLegMigraine], {'Control', 'Migraine'}, 'Location', 'northeast', 'Box', 'off');
    lgd.FontSize = 20; box off; xlim([0.4 2.6]);
end

%% Quality Control Histograms & fVal Plots
if options.fVal
    fValsMigraine = migraineFits.fValMatrix(:);
    fValsControl  = controlFits.fValMatrix(:);
    
    allData = [fValsMigraine; fValsControl];
    edges = linspace(min(allData), max(allData), 20);
    
    figure('Color', 'w'); hold on;
    histogram(fValsMigraine, edges, 'FaceColor', colMigraineHigh, 'FaceAlpha', 0.65, 'EdgeColor', colMigraineHigh * 0.7, 'LineWidth', 1.2);
    histogram(fValsControl, edges, 'FaceColor', colControlHigh, 'FaceAlpha', 0.65, 'EdgeColor', colControlHigh * 0.7, 'LineWidth', 1.2);
    xlabel('Negative log-likelihood (fVal)'); ylabel('Count');
    legend({'Migrainers', 'Controls'}, 'Box', 'off', 'Location', 'northeast');
    title('Model fit quality across groups'); box off; grid off;
    
    figFVal = figure('Color', 'w', 'Name', 'Fit Quality Across Conditions');
    figFVal.Units = 'pixels'; figFVal.Position = [100 100 900 900];
    
    yMaxFVal = 55; panelIdx = 1;
    for l = 1:2
        for c = 1:2
            subplot(2, 2, panelIdx);
            ax = gca; set(ax, 'FontSize', 14, 'FontName', 'Helvetica'); hold on;
            
            mMeanfVal = squeeze(mean(migraineFits.fValMatrix(:,c,l,:), 1));
            mSEMfVal  = squeeze(std(migraineFits.fValMatrix(:,c,l,:), [], 1)) / sqrt(nSubjM);
            cMeanfVal = squeeze(mean(controlFits.fValMatrix(:,c,l,:), 1));
            cSEMfVal  = squeeze(std(controlFits.fValMatrix(:,c,l,:), [], 1)) / sqrt(nSubjC);
            
            errorbar(refFreqHz, mMeanfVal, mSEMfVal, '-o', 'Color', colMigraineHigh, 'MarkerFaceColor', colMigraineHigh, 'LineWidth', 1.8, 'MarkerSize', 11);
            errorbar(refFreqHz, cMeanfVal, cSEMfVal, '-s', 'Color', colControlHigh, 'MarkerFaceColor', colControlHigh, 'LineWidth', 1.8, 'MarkerSize', 11);
            
            ylim([0 yMaxFVal]); xlim([min(refFreqHz)*0.9, max(refFreqHz)*1.1]);
            
            if l == 1
                xl = [min(refFreqHz)*0.85, max(refFreqHz)*1.15];
                p = patch([xl(1) xl(2) xl(2) xl(1)], [0 0 yMaxFVal yMaxFVal], [0.92 0.92 0.92], 'EdgeColor', 'none', 'FaceAlpha', 0.5);
                uistack(p, 'bottom');
            end
            
            xlabel('Reference Frequency (Hz)'); ylabel('Negative log-likelihood (fVal)');
            title(sprintf('%s | %s', lightLabels{l}, contrastLabels{c}));
            xticks([10 13 17 23 30]); axis square; box off; grid off; set(ax, 'XScale', 'log');
            
            if panelIdx == 1
                hL_M = plot(NaN, NaN, '-o', 'Color', colMigraineHigh, 'MarkerFaceColor', colMigraineHigh, 'LineWidth', 1.8, 'MarkerSize', 11);
                hL_C = plot(NaN, NaN, '-s', 'Color', colControlHigh, 'MarkerFaceColor', colControlHigh, 'LineWidth', 1.8, 'MarkerSize', 11);
                lgd = legend([hL_M, hL_C], {'Migraine', 'Control'}, 'Location', 'northeast', 'Box', 'off');
                lgd.ItemTokenSize = [30, 18];
            end
            panelIdx = panelIdx + 1;
        end
    end
end

%% Omnibus ANOVAs & Output Struct Population
if options.anova && ~options.superSubj
    sigmaTestAll = cat(1, sigmaTestM, sigmaTestC);
    sigmaRefAll  = cat(1, sigmaRefM, sigmaRefC);
    [nS, nC, nL, nF] = size(sigmaTestAll);
    [S_idx, C_idx, L_idx, F_idx] = ndgrid(1:nS, 1:nC, 1:nL, 1:nF);
    
    nMigraine = size(sigmaTestM, 1);
    G_idx = ones(nS, nC, nL, nF);
    G_idx((nMigraine+1):end, :, :, :) = 2;
    
    nest = zeros(5, 5); nest(1, 2) = 1;
    factors = {S_idx(:), G_idx(:), C_idx(:), L_idx(:), F_idx(:)};
    varnames = {'Subject', 'Group', 'Contrast', 'LightLevel', 'Frequency'};
    
    fprintf('Running ANOVA for Sigma Test...\n');
    [pTest, tblTest, statsTest] = anovan(sigmaTestAll(:), factors, ...
        'nested', nest, 'random', 1, 'model', 3, 'varnames', varnames, 'display', 'off');
        
    fprintf('Running ANOVA for Sigma Ref...\n');
    [pRef, tblRef, statsRef] = anovan(sigmaRefAll(:), factors, ...
        'nested', nest, 'random', 1, 'model', 3, 'varnames', varnames, 'display', 'off');
        
    output.anova.sigmaTest.pValues   = pTest;
    output.anova.sigmaTest.table     = tblTest;
    output.anova.sigmaTest.stats     = statsTest;
    
    output.anova.sigmaRef.pValues    = pRef;
    output.anova.sigmaRef.table      = tblRef;
    output.anova.sigmaRef.stats      = statsRef;
    
    T_sigmaTest = table(G_idx(:), C_idx(:), L_idx(:), F_idx(:), sigmaTestAll(:), ...
        'VariableNames', {'Group', 'Contrast', 'Light', 'Freq', 'SigmaTest'});
    T_sigmaRef  = table(G_idx(:), C_idx(:), L_idx(:), F_idx(:), sigmaRefAll(:), ...
        'VariableNames', {'Group', 'Contrast', 'Light', 'Freq', 'SigmaRef'});
        
    output.summary.sigmaTest = grpstats(T_sigmaTest, {'Group', 'Contrast', 'Light', 'Freq'}, {'mean', 'std', 'sem'});
    output.summary.sigmaRef  = grpstats(T_sigmaRef,  {'Group', 'Contrast', 'Light', 'Freq'}, {'mean', 'std', 'sem'});
end

end

function out = if_then(cond, a, b)
if cond, out = a; else, out = b; end
end