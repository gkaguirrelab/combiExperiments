function output = individualFitsAnalysis(options)
%Performs statistical analysis and visualization of
% sigma fit parameters (sigmaTest and sigmaRef) from dichoptic flicker experiments.
%
%   INDIVIDUALFITSANALYSIS(OPTIONS) loads model fit parameters across experimental
%   conditions (Contrasts x Light Levels x Frequencies) for Migraine and Control
%   groups (or super-subjects), generates comparative figures, and conducts
%   omnibus ANOVAs.
%
%   INPUT OPTIONS (Name-Value Pairs):
%     barPlot      - (Logical) Generate bar charts comparing sigma values across
%                    contrast/light conditions and group difference interactions.
%                    Default: false
%     fVal         - (Logical) Plot negative log-likelihood (fit quality) distributions
%                    and condition-wise comparisons. Default: false
%     anova        - (Logical) Run 5-way nested mixed-effects ANOVAs (Subject nested
%                    in Group) for both sigmaTest and sigmaRef, and plot fit
%                    parameter distributions. Default: true
%     superSubj    - (Logical) Flag to load pooled "super-subject" data instead
%                    of individual subject fit files. Default: false
%     effectOfFreq - (Logical) Plot main effect of reference frequency on sigma
%                    parameters averaged across groups or conditions. Default: false
% Define the arguments block
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
    % Extract pooled data (cell arrays)
    controlCells  = squeeze(fits.sigmaPooled(1,:,:,:));
    migraineCells = squeeze(fits.sigmaPooled(2,:,:,:));
    
    % Get dimensions
    [nContrasts, nLightLevels, nFreqs] = size(controlCells);
    
    % Preallocate numeric arrays (no subject dimension)
    sigmaTestC = zeros(1,nContrasts,nLightLevels,nFreqs);
    sigmaRefC  = zeros(1,nContrasts,nLightLevels,nFreqs);
    sigmaTestM = zeros(1,nContrasts,nLightLevels,nFreqs);
    sigmaRefM  = zeros(1,nContrasts,nLightLevels,nFreqs);
    
    % Convert from cell to numeric
    for c = 1:nContrasts
        for l = 1:nLightLevels
            for f = 1:nFreqs
                valsC = controlCells{c,l,f};   % [sigmaTest sigmaRef]
                valsM = migraineCells{c,l,f};
                sigmaTestC(1,c,l,f) = valsC(1);
                sigmaRefC(1,c,l,f)  = valsC(2);
                sigmaTestM(1,c,l,f) = valsM(1);
                sigmaRefM(1,c,l,f)  = valsM(2);
            end
        end
    end
    
    % Define pseudo subject count for super subjs
    nSubjC = 1;
    nSubjM = 1;
else
    % data is subj x contrasts x lightLevels x freqs
    migraineFits = load(migraineFilePath);
    controlFits  = load(controlFilePath);
    
    % pull out variables
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
% define labels
contrastLabels = {'lo', 'hi'};
NDLabel = {'3.0', '0.5'};
if options.superSubj
    refFreqHz = fits.refFreqHz;
else
    refFreqHz = migraineFits.refFreqHz;
end
%% Global Color Palette Definitions (Magenta/Plum & Slate-Teal Blue)
colMigraineHigh = [0.72 0.22 0.48]; % Muted Deep Magenta / Plum (High Contrast / Main)
colMigraineLow  = [0.88 0.55 0.72]; % Soft Dusty Pink-Magenta (Low Contrast)
colControlHigh  = [0.18 0.48 0.62]; % Slate / Deep Teal-Blue (High Contrast / Main)
colControlLow   = [0.55 0.76 0.85]; % Soft Sky-Teal Blue (Low Contrast)
%% Calculate Mean and SEM
muSigmaTestC  = squeeze(mean(mean(sigmaTestC,  4),1));
muSigmaTestM   = squeeze(mean(mean(sigmaTestM,  4),1));
semSigmaTestC = squeeze(std(mean(sigmaTestC,  4),  [], 1) ./ sqrt(nSubjC));
semSigmaTestM  = squeeze(std(mean(sigmaTestM,  4), [], 1) ./ sqrt(nSubjM));
muSigmaRefC  = squeeze(mean(mean(sigmaRefC,  4),1));
muSigmaRefM   = squeeze(mean(mean(sigmaRefM,  4),1));
semSigmaRefC = squeeze(std(mean(sigmaRefC,  4),  [], 1) ./ sqrt(nSubjC));
semSigmaRefM  = squeeze(std(mean(sigmaRefM,  4), [], 1) ./ sqrt(nSubjM));
%% Plot all data (Sigma Test) - Vectorized to prevent "Data 1" legends & with uniform freq ticks
for l = 1:2
    f = figure('Color', 'w', 'Name', ['Light Level ' num2str(l)]);
    ax = gca;
    set(ax, 'FontSize', 16);
    hold on;
    
    hHandles = [];
    hNames   = {};
    
    for c = 1:2
        mMean = squeeze(mean(sigmaTestM(:,c,l,:), 1));
        mSEM  = squeeze(std(sigmaTestM(:,c,l,:), [], 1)) / sqrt(nSubjM);
        cMean = squeeze(mean(sigmaTestC(:,c,l,:), 1));
        cSEM  = squeeze(std(sigmaTestC(:,c,l,:), [], 1)) / sqrt(nSubjC);
        
        if c == 1
            fColM = [1 1 1]; fColC = [1 1 1]; lStyle = '--';
            cName = 'Low Contrast';
            cColorM = colMigraineLow; cColorC = colControlLow;
        else
            fColM = colMigraineHigh; fColC = colControlHigh; lStyle = '-';
            cName = 'High Contrast';
            cColorM = colMigraineHigh; cColorC = colControlHigh;
        end
        
        % Plot Migraine & Control with LegendInformation turned off to prevent Data 1 bugs
        hM = errorbar(refFreqHz, mMean, mSEM, ['o' lStyle], 'Color', cColorM, ...
            'MarkerFaceColor', fColM, 'LineWidth', 1.5, 'MarkerSize', 7);
        hM.Annotation.LegendInformation.IconDisplayStyle = 'off';
        
        hC = errorbar(refFreqHz, cMean, cSEM, ['o' lStyle], 'Color', cColorC, ...
            'MarkerFaceColor', fColC, 'LineWidth', 1.5, 'MarkerSize', 7);
        hC.Annotation.LegendInformation.IconDisplayStyle = 'off';
        
        % Store handles for manual legend creation
        hHandles = [hHandles, hM, hC];
        hNames   = [hNames, {['Migraine (' cName ')'], ['Control (' cName ')']}];
    end
    
    xlabel('Reference Frequency (Hz)');
    ylabel('Sigma Test');
    title(['Light Level: ' char(if_then(l==1, "Low", "High"))]);
    ylim([0 4]);
    xlim([min(refFreqHz)*0.9, max(refFreqHz)*1.1]);
    xticks([10 13 17 23 30]);
    yticks([1:4]);
    box off; grid off;
    set(ax, 'XScale', 'log');
    
    if l == 1
        xl = xlim; yl = ylim;
        p = patch([xl(1) xl(2) xl(2) xl(1)], [yl(1) yl(1) yl(2) yl(2)], ...
            [0.9 0.9 0.9], 'EdgeColor', 'none', 'FaceAlpha', 0.5, 'Clipping', 'off');
        uistack(p, 'bottom');
        p.Annotation.LegendInformation.IconDisplayStyle = 'off';
    end
    
    legend(hHandles, hNames, 'Location', 'northwest', 'Box', 'off');
end
% Loop through light levels for sigma ref
for l = 1:2
    f = figure('Color', 'w', 'Name', ['Light Level ' num2str(l)]);
    set(gca, 'FontSize', 16);
    hold on;
    
    hHandles = [];
    hNames   = {};
    
    for c = 1:2
        mMean = squeeze(mean(sigmaRefM(:,c,l,:), 1));
        mSEM  = squeeze(std(sigmaRefM(:,c,l,:), [], 1)) / sqrt(nSubjM);
        cMean = squeeze(mean(sigmaRefC(:,c,l,:), 1));
        cSEM  = squeeze(std(sigmaRefC(:,c,l,:), [], 1)) / sqrt(nSubjC);
        
        if c == 1
            fColM = [1 1 1]; fColC = [1 1 1]; lStyle = '--';
            cName = 'Low Contrast';
            cColorM = colMigraineLow; cColorC = colControlLow;
        else
            fColM = colMigraineHigh; fColC = colControlHigh; lStyle = '-';
            cName = 'High Contrast';
            cColorM = colMigraineHigh; cColorC = colControlHigh;
        end
        
        hM = errorbar(refFreqHz, mMean, mSEM, ['o' lStyle], 'Color', cColorM, ...
            'MarkerFaceColor', fColM, 'LineWidth', 1.5, 'MarkerSize', 7);
        hM.Annotation.LegendInformation.IconDisplayStyle = 'off';
        
        hC = errorbar(refFreqHz, cMean, cSEM, ['o' lStyle], 'Color', cColorC, ...
            'MarkerFaceColor', fColC, 'LineWidth', 1.5, 'MarkerSize', 7);
        hC.Annotation.LegendInformation.IconDisplayStyle = 'off';
        
        hHandles = [hHandles, hM, hC];
        hNames   = [hNames, {['Migraine (' cName ')'], ['Control (' cName ')']}];
    end
    
    xlabel('Reference Frequency (Hz)');
    ylabel('Sigma Ref');
    title(['Light Level: ' char(if_then(l==1, "Low", "High"))]);
    ylim([0 4]);
    xticks([10 13 17 23 30]);
    xlim([min(refFreqHz)*0.9, max(refFreqHz)*1.1]);
    box off; grid off;
    set(gca, 'XScale', 'log');
    
    legend(hHandles, hNames, 'Location', 'northeast', 'Box', 'off');
    
    if l == 1
        xl = xlim; yl = ylim;
        p = patch([xl(1) xl(2) xl(2) xl(1)], [yl(1) yl(1) yl(2) yl(2)], ...
            [0.9 0.9 0.9], 'EdgeColor', 'none', 'FaceAlpha', 0.5, 'Clipping', 'off');
        uistack(p, 'bottom');
    end
end
%% Poster Plot: Effect of Frequency across combined groups
if options.effectOfFreq
    lightLevel    = 2; % High Light
    contrastLevel = 2; % High Contrast
    
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
    
    % Bee Swarm Overlay for Individual Datapoints
    if options.beeSwarm && ~options.superSubj
        nTotalSubj = size(allData, 1);
        jitterWidth = 0.04;
        for fIdx = 1:length(refFreqHz)
            fVal = refFreqHz(fIdx);
            yVals = allData(:, fIdx);
            xJittered = fVal .* (1 + (rand(nTotalSubj, 1) - 0.5) * jitterWidth);
            
            scatter(xJittered, yVals, 45, ...
                'MarkerFaceColor', [0.35 0.35 0.35], ...
                'MarkerEdgeColor', 'none', ...
                'MarkerFaceAlpha', 0.35);
        end
    end
    
    h1 = errorbar(refFreqHz, muSigma, semSigma, ...
        '-', 'Color', 'k', 'LineWidth', 2, 'CapSize', 12, ...
        'Marker', 'o', 'MarkerSize', 18, 'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'w');
    
    h2 = errorbar(refFreqHz, muSigma, semSigma, ...
        'LineStyle', 'none', 'Color', 'k', 'LineWidth', 4, 'CapSize', 14);
    
    uistack(h1,'top');
    
    xlabel('Reference Frequency (Hz)', 'FontSize',35);
    ylabel('$\sigma_{test}$', 'Interpreter', 'latex', 'FontSize',45);
    xlim([min(refFreqHz)*0.9, max(refFreqHz)*1.1]);
    ylim([0 3]);
    set(gca,'XScale','log');
    grid off;
    set(gca,'XMinorGrid','off','YMinorGrid','off');
    box off;
    
    set(gca,'XTickMode','manual');
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
            'LineWidth', 1.5, 'MarkerSize', 7, 'DisplayName','Migraine');
        plot(refFreqHz, meanSigmaTest(2,:), '-s', ...
            'Color', colControlHigh, 'MarkerFaceColor', colControlHigh, ...
            'LineWidth', 1.5, 'MarkerSize', 7, 'DisplayName','Control');
    else
        errorbar(refFreqHz, meanSigmaTest(1,:), semSigmaTest(1,:), '-o', ...
            'Color', colMigraineHigh, 'MarkerFaceColor', colMigraineHigh, 'LineWidth', 1.5, 'MarkerSize', 7, 'DisplayName','Migraine');
        errorbar(refFreqHz, meanSigmaTest(2,:), semSigmaTest(2,:), '-s', ...
            'Color', colControlHigh, 'MarkerFaceColor', colControlHigh, 'LineWidth', 1.5, 'MarkerSize', 7, 'DisplayName','Control');
    end
    set(gca,'XScale','log');
    xlabel('Reference Frequency (Hz)'); ylabel('Sigma Test');
    ylim([0 3]); title('Frequency vs Sigma Test');
    xticks([10 13 17 23 30]);
    legend('Location','northwest'); grid off; box off;
    xlim([min(refFreqHz)*0.9, max(refFreqHz)*1.1]);
    
    % Plot Sigma Ref
    figure('Color','w'); hold on;
    if options.superSubj
        plot(refFreqHz, meanSigmaRef(1,:), '-o', ...
            'Color', colMigraineHigh, 'MarkerFaceColor', colMigraineHigh, ...
            'LineWidth', 1.5, 'MarkerSize', 7, 'DisplayName','Migraine');
        plot(refFreqHz, meanSigmaRef(2,:), '-s', ...
            'Color', colControlHigh, 'MarkerFaceColor', colControlHigh, ...
            'LineWidth', 1.5, 'MarkerSize', 7, 'DisplayName','Control');
    else
        errorbar(refFreqHz, meanSigmaRef(1,:), semSigmaRef(1,:), '-o', ...
            'Color', colMigraineHigh, 'MarkerFaceColor', colMigraineHigh, 'LineWidth', 1.5, 'MarkerSize', 7, 'DisplayName','Migraine');
        errorbar(refFreqHz, meanSigmaRef(2,:), semSigmaRef(2,:), '-s', ...
            'Color', colControlHigh, 'MarkerFaceColor', colControlHigh, 'LineWidth', 1.5, 'MarkerSize', 7, 'DisplayName','Control');
    end
    set(gca,'XScale','log');
    xlabel('Reference Frequency (Hz)'); ylabel('Sigma Ref');
    ylim([0 if_then(options.superSubj, 2.5, 2)]);
    title('Frequency vs Sigma Ref');
    xticks([10 13 17 23 30]);
    legend('Location','northwest'); grid off; box off;
    xlim([min(refFreqHz)*0.9, max(refFreqHz)*1.1]);
end
%% Bar plot: Plotting sigma parameters for each contrast x light level condition
sigmaTest = options.sigmaTest;
if options.barPlot
    reorderIdx = [4 3 2 1];
    
    highLightGroups = [1 2];
    lowLightGroups  = [3 4];
    highContrastGroups = [1 3];
    lowContrastGroups  = [2 4];
    
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
    
    patch([2.5 4.5 4.5 2.5], [0 0 3 3], [0.9 0.9 0.9], ...
        'EdgeColor', 'none', 'FaceAlpha', 0.5);
    
    b = bar(barData, 'grouped');
    
    b(1).FaceColor = 'flat';
    b(2).FaceColor = 'flat';
    
    for g = 1:4
        if ismember(g, lowContrastGroups)
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
                edgeColor = if_then(ismember(g, lowContrastGroups), colControlLow * 0.8, colControlHigh * 0.7);
            else
                edgeColor = if_then(ismember(g, lowContrastGroups), colMigraineLow * 0.8, colMigraineHigh * 0.7);
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
            cEdge = if_then(ismember(g, lowContrastGroups), colControlLow * 0.7, colControlHigh * 0.6);
            mEdge = if_then(ismember(g, lowContrastGroups), colMigraineLow * 0.7, colMigraineHigh * 0.6);
            
            % Control Swarm
            yValC = rawControl(:, g);
            xC = xControlCenters(g);
            swarmchart(repmat(xC, size(yValC)), yValC, 60, ...
                'MarkerFaceColor', cEdge, ...
                'MarkerEdgeColor', cEdge * 0.7, ...
                'MarkerFaceAlpha', 0.85, ...
                'XJitter', 'density', ...
                'XJitterWidth', 0.2);
            
            % Migraine Swarm
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
    
    contrastNames = {'High Contrast', 'Low Contrast', 'High Contrast', 'Low Contrast'};
    yContrast = -0.15;
    for i = 1:4
        midPoint = (b(1).XEndPoints(i) + b(2).XEndPoints(i)) / 2;
        text(midPoint, yContrast, contrastNames{i}, ...
            'HorizontalAlignment', 'center', 'FontSize', 32, 'Rotation', 0);
    end
    
    yLight = -0.35;
    text(1.5, yLight, 'High Light', 'HorizontalAlignment', 'center', ...
        'FontWeight', 'bold', 'FontSize', 35, 'Clipping', 'off');
    text(3.5, yLight, 'Low Light', 'HorizontalAlignment', 'center', ...
        'FontWeight', 'bold', 'FontSize', 35, 'Clipping', 'off');
end
%% Bar plot for interaction: High vs Low light effect on sigma test (per group)
if options.barPlot
    mLight = squeeze(mean(mean(sigmaTestM, 4), 2));
    cLight = squeeze(mean(mean(sigmaTestC, 4), 2));
    
    mDiff = mLight(:,2) - mLight(:,1);
    cDiff = cLight(:,2) - cLight(:,1);
    
    groupMean = [mean(cDiff), mean(mDiff)];
    groupSEM  = [std(cDiff)/sqrt(numel(cDiff)), std(mDiff)/sqrt(numel(mDiff))];
    
    fig = figure('Color','w');
    fig.Units = 'pixels';
    fig.Position = [100 100 800 600];
    set(fig,'InvertHardcopy','off');
    
    ax = gca;
    ax.FontName = 'Helvetica';
    ax.FontSize = 35;
    ax.LineWidth = 1.5;
    hold on;
    
    % FULL-AXIS GRAY PATCH FOR UPPER REGION OF DELTA SIGMA PLOT
    ylLimFull = ylim;
    xlLimFull = xlim;
    patch([xlLimFull(1) xlLimFull(2) xlLimFull(2) xlLimFull(1)], [0 0 ylLimFull(2) ylLimFull(2)], [0.9 0.9 0.9], ...
        'EdgeColor', 'none', 'FaceAlpha', 0.4, 'Clipping', 'off');
    uistack(findobj(ax, 'Type', 'patch'), 'bottom'); % Send patch to background

    x = 1:2;
    b = bar(x, groupMean, 'FaceColor','flat','BarWidth', 0.5);
    
    b.CData(1,:) = colControlHigh;
    b.CData(2,:) = colMigraineHigh;
    
    errorbar(x, groupMean, groupSEM, 'k', ...
        'LineStyle','none', ...
        'LineWidth',2.5);
    
    if options.beeSwarm && ~options.superSubj
        swarmchart(repmat(1, size(cDiff)), cDiff, 60, ...
            'MarkerFaceColor', colControlHigh * 0.7, ...
            'MarkerEdgeColor', colControlHigh * 0.5, ...
            'MarkerFaceAlpha', 0.85, ...
            'XJitter', 'density', ...
            'XJitterWidth', 0.15);
        
        swarmchart(repmat(2, size(mDiff)), mDiff, 60, ...
            'MarkerFaceColor', colMigraineHigh * 0.7, ...
            'MarkerEdgeColor', colMigraineHigh * 0.5, ...
            'MarkerFaceAlpha', 0.85, ...
            'XJitter', 'density', ...
            'XJitterWidth', 0.15);
    end
    
    set(gca,'XTick',x,'XTickLabel',{'Control','Migraine'});
    ylabel('$\Delta \sigma_{\mathrm{\it{test}}}$', ...
        'Interpreter', 'latex', 'FontSize', 45);
    box off;
    ylim padded;
end
%% Quality Control Histograms (fVal)
if options.fVal
    fValsMigraine = migraineFits.fValMatrix(:);
    fValsControl  = controlFits.fValMatrix(:);
    
    allData = [fValsMigraine; fValsControl];
    edges = linspace(min(allData), max(allData), 20);
    
    figure('Color', 'w'); hold on;
    h1 = histogram(fValsMigraine, edges, ...
        'FaceColor', colMigraineHigh, ...
        'FaceAlpha', 0.65, ...
        'EdgeColor', colMigraineHigh * 0.7, ...
        'LineWidth', 1.2);
        
    h2 = histogram(fValsControl, edges, ...
        'FaceColor', colControlHigh, ...
        'FaceAlpha', 0.65, ...
        'EdgeColor', colControlHigh * 0.7, ...
        'LineWidth', 1.2);
        
    xlabel('Negative log-likelihood (fVal)');
    ylabel('Count');
    legend({'Migrainers', 'Controls'}, 'Box', 'off', 'Location', 'northeast');
    title('Model fit quality across groups');
    box off; grid off;
    
    for l = 1:2
        f = figure('Color', 'w', 'Name', ['Light Level ' num2str(l)]);
        hold on;
        hHandles = [];
        hNames   = {};
        
        for c = 1:2
            mMeanfVal = squeeze(mean(migraineFits.fValMatrix(:,c,l,:), 1));
            mSEMfVal  = squeeze(std(migraineFits.fValMatrix(:,c,l,:), [], 1)) / sqrt(nSubjM);
            cMeanfVal = squeeze(mean(controlFits.fValMatrix(:,c,l,:), 1));
            cSEMfVal  = squeeze(std(controlFits.fValMatrix(:,c,l,:), [], 1)) / sqrt(nSubjC);
            
            if c == 1
                fColM = [1 1 1]; fColC = [1 1 1]; lStyle = '--';
                cName = 'Low Contrast';
                cColorM = colMigraineLow; cColorC = colControlLow;
            else
                fColM = colMigraineHigh; fColC = colControlHigh; lStyle = '-';
                cName = 'High Contrast';
                cColorM = colMigraineHigh; cColorC = colControlHigh;
            end
            
            hM = errorbar(refFreqHz, mMeanfVal, mSEMfVal, ['o' lStyle], 'Color', cColorM, ...
                'MarkerFaceColor', fColM, 'LineWidth', 1.5, 'MarkerSize', 7);
            hM.Annotation.LegendInformation.IconDisplayStyle = 'off';
            
            hC = errorbar(refFreqHz, cMeanfVal, cSEMfVal, ['o' lStyle], 'Color', cColorC, ...
                'MarkerFaceColor', fColC, 'LineWidth', 1.5, 'MarkerSize', 7);
            hC.Annotation.LegendInformation.IconDisplayStyle = 'off';
            
            hHandles = [hHandles, hM, hC];
            hNames   = [hNames, {['Migraine (' cName ')'], ['Control (' cName ')']}];
        end
        
        xlabel('Reference Frequency (Hz)');
        ylabel('Negative log-likelihood (fVal)');
        title(['Light Level: ' char(if_then(l==1, "Low", "High"))]);
        xlim([min(refFreqHz)*0.9, max(refFreqHz)*1.1]);
        xticks([10 13 17 23 30]);
        box off; grid off;
        set(gca, 'XScale', 'log');
        legend(hHandles, hNames, 'Location', 'northeast', 'Box', 'off');
        
        if l == 1
            xl = xlim; yl = ylim;
            p = patch([xl(1) xl(2) xl(2) xl(1)], [yl(1) yl(1) yl(2) yl(2)], ...
                [0.9 0.9 0.9], 'EdgeColor', 'none', 'FaceAlpha', 0.5, 'Clipping', 'off');
            uistack(p, 'bottom');
        end
    end
    
    meanMigfValAll = squeeze(mean(mean(mean(migraineFits.fValMatrix, 1),2),3));
    migstdValAll   = std(migraineFits.fValMatrix, 0, [1 2 3]);
    migSEMValAll   = squeeze(migstdValAll / sqrt(nSubjM));
    
    meanContfValAll = squeeze(mean(mean(mean(controlFits.fValMatrix, 1),2),3));
    contstdValAll   = std(controlFits.fValMatrix, 0, [1 2 3]);
    contSEMValAll   = squeeze(contstdValAll / sqrt(nSubjC));
    
    figure('Color','w'); hold on;
    errorbar(refFreqHz, meanMigfValAll, migSEMValAll, '-o', ...
        'Color', colMigraineHigh, 'MarkerFaceColor', colMigraineHigh, 'LineWidth', 1.5, 'MarkerSize', 7, 'DisplayName','Migraine');
    errorbar(refFreqHz, meanContfValAll, contSEMValAll, '-s', ...
        'Color', colControlHigh, 'MarkerFaceColor', colControlHigh, 'LineWidth', 1.5, 'MarkerSize', 7, 'DisplayName','Control');
    
    set(gca,'XScale','log');
    xlabel('Reference Frequency (Hz)'); 
    ylabel('Negative log-likelihood (fVal)');
    title('Frequency vs Fit Quality');
    xticks([10 13 17 23 30]);
    legend('Location','northwest', 'Box', 'off'); 
    grid off; box off;
    xlim([min(refFreqHz)*0.9, max(refFreqHz)*1.1]);
end
%% Omnibus ANOVAS
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
    
    fprintf('Running ANOVA for Sigma Test...\n');
    [p, tbl, stats] = anovan(sigmaTestAll(:), factors, ...
        'nested', nest, ...
        'random', 1, ... 
        'model', 3, ...   
        'varnames', varnames);
    fprintf('\nRunning ANOVA for Sigma Ref...\n');
    [pZero, tblZero, statsZero] = anovan(sigmaRefAll(:), factors, ...
        'nested', nest, ...
        'random', 1, ...
        'model', 3, ...    
        'varnames', varnames);
        
    G_labels = {'Migraine', 'Control'};
    C_labels = {'Low', 'High'};
    L_labels = {'Low', 'High'};
    F_labels = {'Freq1', 'Freq2', 'Freq3', 'Freq4', 'Freq5'}; 
    
    T_sigma = table(G_idx(:), C_idx(:), L_idx(:), F_idx(:), sigmaTestAll(:), ...
        'VariableNames', {'Group', 'Contrast', 'Light', 'Freq', 'Sigma'});
    grpstats(T_sigma, {'Group', 'Contrast', 'Light', 'Freq'}, 'mean')
    
    testM = sigmaTestM(:);
    testC = sigmaTestC(:);
    refM  = sigmaRefM(:);
    refC  = sigmaRefC(:);
    
    allTest = [testM; testC];
    allRef  = [refM; refC];
    testEdges = linspace(min(allTest), max(allTest), 40);
    refEdges  = linspace(min(allRef), max(allRef), 40);
    
    figure;
    nexttile; hold on;
    set(gca,'FontSize',30);
    set(gca,'TickLabelInterpreter','latex');
    histogram(testM, testEdges, 'FaceColor', [0.8 0.3 0.3], 'FaceAlpha', 0.4, 'EdgeColor', 'none');
    histogram(testC, testEdges, 'FaceColor', [0.3 0.3 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none');
    xlabel('$\sigma$ value', 'Interpreter', 'latex');  ylabel('');
    xticks([0 1 2 3 4 5]);
    yticks([0 10 20 30 40]);
    legend({'Migraine', 'Control'}, 'Box', 'off', 'Interpreter', 'latex');
    box off; grid off;
end

end

% Helper function for title logic
function out = if_then(cond, a, b)
if cond, out = a; else, out = b; end
end