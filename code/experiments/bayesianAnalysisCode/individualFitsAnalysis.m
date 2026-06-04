function output = individualFitsAnalysis(options)
% Define the arguments block
arguments
    options.barPlot (1,1) logical = false
    options.fVal (1,1) logical = false
    options.anova (1,1) logical = true
    options.superSubj (1,1) logical = false
    options.effectOfFreq (1,1) logical = false
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
    migraineFilePath = fullfile(dataDir, '15Migrainer_individualSigmaFitsConstrained.mat');
    controlFilePath  = fullfile(dataDir, '15Control_individualSigmaFitsConstrained.mat');
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

%% Calculate Mean and SEM
% calculate mean across ref freq and subj and SEM
muSigmaTestC  = squeeze(mean(mean(sigmaTestC,  4),1));
muSigmaTestM   = squeeze(mean(mean(sigmaTestM,  4),1));
semSigmaTestC = squeeze(std(mean(sigmaTestC,  4),  [], 1) ./ sqrt(nSubjC));
semSigmaTestM  = squeeze(std(mean(sigmaTestM,  4), [], 1) ./ sqrt(nSubjM));

muSigmaRefC  = squeeze(mean(mean(sigmaRefC,  4),1));
muSigmaRefM   = squeeze(mean(mean(sigmaRefM,  4),1));
semSigmaRefC = squeeze(std(mean(sigmaRefC,  4),  [], 1) ./ sqrt(nSubjC));
semSigmaRefM  = squeeze(std(mean(sigmaRefM,  4), [], 1) ./ sqrt(nSubjM));

%% Plot all data
%  Prepare Colors
colMigraine = [0.8 0.3 0.3];
colControl  = [0.3 0.3 0.8];

% Loop through light levels (1 = Low, 2 = High)
for l = 1:2
    f = figure('Color', 'w', 'Name', ['Light Level ' num2str(l)]);
    set(gca, 'FontSize', 16);
    hold on;

    % Store handles for the legend
    hHandles = [];
    hNames   = {};

    % Loop through Contrasts (1 = Low, 2 = High)
    for c = 1:2
        % Calculate Means and SEMs
        mMean = squeeze(mean(sigmaTestM(:,c,l,:), 1));
        mSEM  = squeeze(std(sigmaTestM(:,c,l,:), [], 1)) / sqrt(nSubjM);
        cMean = squeeze(mean(sigmaTestC(:,c,l,:), 1));
        cSEM  = squeeze(std(sigmaTestC(:,c,l,:), [], 1)) / sqrt(nSubjC);

        % Styling Logic
        % c=1: Low Contrast (White Fill, Dashed)
        % c=2: High Contrast (Color Fill, Solid)
        if c == 1
            fColM = [1 1 1]; fColC = [1 1 1]; lStyle = '--';
            cName = 'Low Contrast';
        else
            fColM = colMigraine; fColC = colControl; lStyle = '-';
            cName = 'High Contrast';
        end

        % Plot Migraine
        hM = errorbar(refFreqHz, mMean, mSEM, ['o' lStyle], 'Color', colMigraine, ...
            'MarkerFaceColor', fColM, 'LineWidth', 1.5, 'MarkerSize', 7);

        hM.DisplayName = ['Migraine (' cName ')'];

        % Plot Control
        hC = errorbar(refFreqHz, cMean, cSEM, ['o' lStyle], 'Color', colControl, ...
            'MarkerFaceColor', fColC, 'LineWidth', 1.5, 'MarkerSize', 7);

        hC.DisplayName = ['Control (' cName ')', ''];

        % Add to legend lists
        % hHandles = [hHandles, hM, hC];
        % hNames   = [hNames, {['Migraine (' cName ')'], ['Control (' cName ')']}];
    end

    % Styling
    xlabel('Reference Frequency (Hz)');
    ylabel('Sigma Test');
    title(['Light Level: ' char(if_then(l==1, "Low", "High"))]);
    ylim([0 4]);
    xlim([min(refFreqHz)*0.9, max(refFreqHz)*1.1]);
    box off;
    grid on;
    set(gca, 'XScale', 'log');

    % --- Add Grey Background (Only for Low Light, l=1) ---
    if l == 1
        xl = xlim; yl = ylim;
        p = patch([xl(1) xl(2) xl(2) xl(1)], [yl(1) yl(1) yl(2) yl(2)], ...
            [0.9 0.9 0.9], 'EdgeColor', 'none', 'FaceAlpha', 0.5, 'Clipping', 'off');
        uistack(p, 'bottom'); % Ensure it stays behind the data
        p.Annotation.LegendInformation.IconDisplayStyle = 'off';
    end

    % Add Legend
    legend('show', 'Location', 'northwest', 'Box', 'off');
end

% again for sigma ref

% Loop through light levels (1 = Low, 2 = High)
for l = 1:2
    f = figure('Color', 'w', 'Name', ['Light Level ' num2str(l)]);
    set(gca, 'FontSize', 16);
    hold on;

    % Store handles for the legend
    hHandles = [];
    hNames   = {};

    % Loop through Contrasts (1 = Low, 2 = High)
    for c = 1:2
        % Calculate Means and SEMs
        mMean = squeeze(mean(sigmaRefM(:,c,l,:), 1));
        mSEM  = squeeze(std(sigmaRefM(:,c,l,:), [], 1)) / sqrt(15);
        cMean = squeeze(mean(sigmaRefC(:,c,l,:), 1));
        cSEM  = squeeze(std(sigmaRefC(:,c,l,:), [], 1)) / sqrt(15);

        % Styling Logic
        % c=1: Low Contrast (White Fill, Dashed)
        % c=2: High Contrast (Color Fill, Solid)
        if c == 1
            fColM = [1 1 1]; fColC = [1 1 1]; lStyle = '--';
            cName = 'Low Contrast';
        else
            fColM = colMigraine; fColC = colControl; lStyle = '-';
            cName = 'High Contrast';
        end

        % Plot Migraine
        hM = errorbar(refFreqHz, mMean, mSEM, ['o' lStyle], 'Color', colMigraine, ...
            'MarkerFaceColor', fColM, 'LineWidth', 1.5, 'MarkerSize', 7);

        % Plot Control
        hC = errorbar(refFreqHz, cMean, cSEM, ['o' lStyle], 'Color', colControl, ...
            'MarkerFaceColor', fColC, 'LineWidth', 1.5, 'MarkerSize', 7);

        % Add to legend lists
        hHandles = [hHandles, hM, hC];
        hNames   = [hNames, {['Migraine (' cName ')'], ['Control (' cName ')']}];
    end

    % Styling
    xlabel('Reference Frequency (Hz)');
    ylabel('Sigma Ref');
    title(['Light Level: ' char(if_then(l==1, "Low", "High"))]);
    ylim([0 4]);
    xlim([min(refFreqHz)*0.9, max(refFreqHz)*1.1]);
    box off;
    grid on;
    set(gca, 'XScale', 'log');

    % Add Legend
    legend(hHandles, hNames, 'Location', 'northeast', 'Box', 'off');

    % --- Add Grey Background (Only for Low Light, l=1) ---
    if l == 1
        xl = xlim; yl = ylim;
        p = patch([xl(1) xl(2) xl(2) xl(1)], [yl(1) yl(1) yl(2) yl(2)], ...
            [0.9 0.9 0.9], 'EdgeColor', 'none', 'FaceAlpha', 0.5, 'Clipping', 'off');
        uistack(p, 'bottom'); % Ensure it stays behind the data
    end
end

%%
% For the poster: Plot of the sigma test value across frequencies at 
% high light level, high contrast, averaged over migraine and control.

if options.effectOfFreq
    % Conditions
    lightLevel    = 2; % High Light
    contrastLevel = 2; % High Contrast

    % Combine groups

    % Get subject means
    mData = squeeze(sigmaTestM(:,contrastLevel,lightLevel,:)); % subj x freq
    cData = squeeze(sigmaTestC(:,contrastLevel,lightLevel,:));

    allData = [mData; cData];

    % Mean + SEM across all subjects
    muSigma = mean(allData,1);
    semSigma = std(allData,[],1) ./ sqrt(size(allData,1));

    fig = figure('Color','w');
    % CONSISTENT EXPORT SIZE
    fig.Units = 'pixels';
    fig.Position = [100 100 1400 450];
    % White background
    set(fig,'InvertHardcopy','off');
    ax = gca;
    % GLOBAL FONT SETTINGS
    ax.FontName = 'Helvetica';
    ax.FontSize = 35;
    ax.LineWidth = 1.5;
    hold on;

    % Main line
    h1 = errorbar(refFreqHz, muSigma, semSigma, ...
        '-', ...
        'Color', 'k', ...
        'LineWidth', 2, ...
        'CapSize', 12, ...
        'Marker', 'o', ...
        'MarkerSize', 18, ...
        'MarkerFaceColor', 'k', ...
        'MarkerEdgeColor', 'w');

    hold on;

    % Overlay thicker error bars ONLY (no markers)
    h2 = errorbar(refFreqHz, muSigma, semSigma, ...
        'LineStyle', 'none', ...
        'Color', 'k', ...
        'LineWidth', 4, ...
        'CapSize', 14);

    % push markers to front
    uistack(h1,'top');

    % Styling

    xlabel('Reference Frequency (Hz)', 'FontSize',35);
    ylabel('$\sigma_{test}$', 'Interpreter', 'latex', 'FontSize',45);

    % title('Sigma Test Across Frequencies');

    xlim([min(refFreqHz)*0.9, max(refFreqHz)*1.1]);

    ylim([0 2.5]);

    set(gca,'XScale','log');
    grid on;
    set(gca,'XMinorGrid','off','YMinorGrid','off');
    box off;

    % Optional: make ticks prettier
    set(gca,'XTickMode','manual');
    set(gca,'XTick',[10 13 17 23 30]);
end

%% Plots to examine main effect of frequency  
% Average Sigma across Contrast and Light, keep Group and Frequency

if options.effectOfFreq
    % Pull data
    sigmaTestData = cat(1, sigmaTestM, sigmaTestC);  % [Subjects × Contrast × Light × Freq] OR [Group x ... ]
    sigmaRefData  = cat(1, sigmaRefM, sigmaRefC);

    % Group labels
    nMigraine = size(sigmaTestM,1);
    groupLabels = [ones(nMigraine,1); 2*ones(size(sigmaTestC,1),1)];
    groups = unique(groupLabels);

    % Preallocate mean & SEM
    nFreqs = length(refFreqHz);
    meanSigmaTest = zeros(length(groups), nFreqs);
    semSigmaTest  = zeros(length(groups), nFreqs);
    meanSigmaRef  = zeros(length(groups), nFreqs);
    semSigmaRef   = zeros(length(groups), nFreqs);

    for g = 1:length(groups)
        idx = groupLabels == groups(g);

        % Average across Contrast x Light
        dataTest = squeeze(mean(mean(sigmaTestData(idx,:,:,:),3),2)); % [Subjects × Freq] OR [Group x Freq]
        dataRef  = squeeze(mean(mean(sigmaRefData(idx,:,:,:),3),2));

        if options.superSubj
            meanSigmaTest(g,:) = dataTest;   % already [1 × freq]
            semSigmaTest(g,:)  = nan;        % no SEM

            meanSigmaRef(g,:) = dataRef;   % already [1 × freq]
            semSigmaRef(g,:)  = nan;        % no SEM
        else
            meanSigmaTest(g,:) = mean(dataTest,1); % average across subjects
            semSigmaTest(g,:)  = std(dataTest,0,1)/sqrt(sum(idx));

            meanSigmaRef(g,:) = mean(dataRef,1);
            semSigmaRef(g,:)  = std(dataRef,0,1)/sqrt(sum(idx));
        end

    end

    % Plot Sigma Test
    figure('Color','w'); hold on;
    colMigraine = [0.8 0.3 0.3];
    colControl  = [0.3 0.3 0.8];

    if options.superSubj
        % Plot mean ONLY
        % Migraine
        plot(refFreqHz, meanSigmaTest(1,:), '-o', ...
            'Color', colMigraine, 'MarkerFaceColor', colMigraine, ...
            'LineWidth', 1.5, 'MarkerSize', 7, 'DisplayName','Migraine');
        % Control
        plot(refFreqHz, meanSigmaTest(2,:), '-s', ...
            'Color', colControl, 'MarkerFaceColor', colControl, ...
            'LineWidth', 1.5, 'MarkerSize', 7, 'DisplayName','Control');
    else
        % Migraine
        errorbar(refFreqHz, meanSigmaTest(1,:), semSigmaTest(1,:), '-o', ...
            'Color', colMigraine, 'MarkerFaceColor', colMigraine, 'LineWidth', 1.5, 'MarkerSize', 7, 'DisplayName','Migraine');
        % Control
        errorbar(refFreqHz, meanSigmaTest(2,:), semSigmaTest(2,:), '-s', ...
            'Color', colControl, 'MarkerFaceColor', colControl, 'LineWidth', 1.5, 'MarkerSize', 7, 'DisplayName','Control');
    end

    set(gca,'XScale','log');
    xlabel('Reference Frequency (Hz)'); ylabel('Sigma Test');
    if options.superSubj
        ylim([0 2.5]);
    else
        ylim([0 2]);
    end
    title('Frequency vs Sigma Test');
    legend('Location','northwest'); grid on; box off;
    xlim([min(refFreqHz)*0.9, max(refFreqHz)*1.1]);

    % Plot Sigma Ref
    figure('Color','w'); hold on;

    if options.superSubj
        % Plot mean ONLY
        % Migraine
        plot(refFreqHz, meanSigmaRef(1,:), '-o', ...
            'Color', colMigraine, 'MarkerFaceColor', colMigraine, ...
            'LineWidth', 1.5, 'MarkerSize', 7, 'DisplayName','Migraine');
        % Control
        plot(refFreqHz, meanSigmaRef(2,:), '-s', ...
            'Color', colControl, 'MarkerFaceColor', colControl, ...
            'LineWidth', 1.5, 'MarkerSize', 7, 'DisplayName','Control');
    else
        % Migraine
        errorbar(refFreqHz, meanSigmaRef(1,:), semSigmaRef(1,:), '-o', ...
            'Color', colMigraine, 'MarkerFaceColor', colMigraine, 'LineWidth', 1.5, 'MarkerSize', 7, 'DisplayName','Migraine');
        % Control
        errorbar(refFreqHz, meanSigmaRef(2,:), semSigmaRef(2,:), '-s', ...
            'Color', colControl, 'MarkerFaceColor', colControl, 'LineWidth', 1.5, 'MarkerSize', 7, 'DisplayName','Control');
    end

    set(gca,'XScale','log');
    xlabel('Reference Frequency (Hz)'); ylabel('Sigma Ref');
    if options.superSubj
        ylim([0 2.5]);
    else
        ylim([0 2]);
    end
    title('Frequency vs Sigma Ref');
    legend('Location','northwest'); grid on; box off;
    xlim([min(refFreqHz)*0.9, max(refFreqHz)*1.1]);
end
%% Bar plot: Plotting sigma parameters for each contrast x light level condition

% Choose sigma test or sigma ref
sigmaTest = false;

if options.barPlot

    % Original order assumed:
    % (1)=LowContrast-LowLight
    % (2)=HighContrast-LowLight
    % (3)=LowContrast-HighLight
    % (4)=HighContrast-HighLight
    reorderIdx = [4 3 2 1];

    % For line style
    highLightGroups = [1 2];
    lowLightGroups  = [3 4];
    highContrastGroups = [1 3];
    lowContrastGroups  = [2 4];

    % Plot sigma test bar plot
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
    % CONSISTENT EXPORT SIZE
    fig.Units = 'pixels';
    fig.Position = [100 100 1800 600];
    % White background
    set(fig,'InvertHardcopy','off');
    ax = gca;
    % GLOBAL FONT SETTINGS
    ax.FontName = 'Helvetica';
    ax.FontSize = 35;
    ax.LineWidth = 1.5;
    hold on;

    % Darkness Patch
    % Spans x=0.5 to 2.5 (covering the last 2 groups: Low Light)
    patch([2.5 4.5 4.5 2.5], [0 0 2.5 2.5], [0.9 0.9 0.9], ...
        'EdgeColor', 'none', 'FaceAlpha', 0.5);

    % Plot Bars
    b = bar(barData, 'grouped');
    b(1).FaceColor = [0.77 0.77 0.80]; % Control
    b(2).FaceColor = [0.72 0.50 0.50];
    % b(2).FaceColor = [0.72 0.50 0.54]; % Migraine

    % --- COLORS ---

    % Base fill colors
    controlColor  = [0.55 0.55 0.60]; % soft gray-blue
    migraineColor = [0.78 0.52 0.56]; % muted dusty rose

    % Make low-contrast versions by blending toward white
    blendAmount = 0.3;

    controlLow  = controlColor  + (1 - controlColor)  * blendAmount;
    migraineLow = migraineColor + (1 - migraineColor) * blendAmount;

    % Darker edge colors
    controlEdge  = controlColor * 0.8;
    migraineEdge = migraineColor * 0.7;

    % Enable per-bar coloring
    b(1).FaceColor = 'flat';
    b(2).FaceColor = 'flat';

    % Assign colors bar-by-bar
    for g = 1:4

        % ----- CONTROL -----
        if ismember(g, lowContrastGroups)
            b(1).CData(g,:) = controlLow;
        else
            b(1).CData(g,:) = controlColor;
        end

        % ----- MIGRAINE -----
        if ismember(g, lowContrastGroups)
            b(2).CData(g,:) = migraineLow;
        else
            b(2).CData(g,:) = migraineColor;
        end
    end

    % Remove default edges
    b(1).EdgeColor = 'none';
    b(2).EdgeColor = 'none';

    % ----- CUSTOM SOLID OUTLINES -----

    for iBar = 1:2

        if iBar == 1
            darkEdge  = controlColor * 0.8;
            lightEdge = controlLow * 0.9;
        else
            darkEdge  = migraineColor * 0.7;
            lightEdge = migraineLow * 0.9;
        end

        for g = 1:4

            xCenter = b(iBar).XEndPoints(g);

            nBars = size(barData,2);
            groupWidth = min(0.8, nBars/(nBars + 1.5));
            width = groupWidth / nBars - 0.06;

            y = barData(g,iBar);

            % Use lighter edge for low contrast
            if ismember(g, lowContrastGroups)
                edgeColor = lightEdge;
            else
                edgeColor = darkEdge;
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

    % Formatting & Labels
    set(gca, 'Layer', 'top', 'Box', 'off');
    if sigmaTest
        ylabel('$\sigma_{test}$', ...
            'Interpreter','latex', ...
            'FontSize',45, ...
            'FontName','Helvetica');
    else
        ylabel('$\sigma_{ref}$', ...
            'Interpreter','latex', ...
            'FontSize',45, ...
            'FontName','Helvetica');
    end
    ylim([0 2.5]);
    xlim([0.5, 4.5]);
    xticks([]); % Turn off default ticks to make room for custom labels
    lgd = legend([b(1), b(2)], {'Control', 'Migraine'}, ...
        'Location', 'Northwest');
    lgd.FontSize = 32;
    lgd.FontName = 'Helvetica';
    lgd.Box = 'off';

    % "Contrast" Labels (Centered between the two bars) ---
    contrastNames = {'High Contrast', 'Low Contrast', 'High Contrast', 'Low Contrast'};
    yContrast = -0.15;
    for i = 1:4
        % Calculate the midpoint between the Control and Migraine bars
        midPoint = (b(1).XEndPoints(i) + b(2).XEndPoints(i)) / 2;
        text(midPoint, yContrast, contrastNames{i}, ...
            'HorizontalAlignment', 'center', 'FontSize', 32, 'Rotation', 0);
    end

    % "Light" Labels (Across bars) ---
    yLight = -0.35; % Lower down to avoid collision
    text(1.5, yLight, 'High Light', 'HorizontalAlignment', 'center', ...
        'FontWeight', 'bold', 'FontSize', 35, 'Clipping', 'off');
    text(3.5, yLight, 'Low Light', 'HorizontalAlignment', 'center', ...
        'FontWeight', 'bold', 'FontSize', 35, 'Clipping', 'off');

end

%% Bar plot for interaction: High vs Low light effect on sigma test (per group)

if options.barPlot
    % --- Collapse across contrast and frequency ---
    % result: subj × lightLevel

    mLight = squeeze(mean(mean(sigmaTestM, 4), 2)); % migraine: subj × light
    cLight = squeeze(mean(mean(sigmaTestC, 4), 2)); % control: subj × light

    % --- Compute difference score: High - Low ---
    % light index: 1 = low, 2 = high

    mDiff = mLight(:,2) - mLight(:,1);
    cDiff = cLight(:,2) - cLight(:,1);

    % --- Combine for plotting ---
    groupMean = [mean(cDiff), mean(mDiff)];
    groupSEM  = [std(cDiff)/sqrt(numel(cDiff)), std(mDiff)/sqrt(numel(mDiff))];

    fig = figure('Color','w');
    % CONSISTENT EXPORT SIZE
    fig.Units = 'pixels';
    fig.Position = [100 100 800 600];
    % White background
    set(fig,'InvertHardcopy','off');
    ax = gca;
    % GLOBAL FONT SETTINGS
    ax.FontName = 'Helvetica';
    ax.FontSize = 35;
    ax.LineWidth = 1.5;
    hold on;

    x = 1:2;

    b = bar(x, groupMean, 'FaceColor','flat','BarWidth', 0.5);

    % Colors
    colControl  = [0.77 0.77 0.80];
    colMigraine = [0.72 0.50 0.50];

    b.CData(1,:) = colControl;
    b.CData(2,:) = colMigraine;

    % Error bars
    errorbar(x, groupMean, groupSEM, 'k', ...
        'LineStyle','none', ...
        'LineWidth',2.5);

    % Styling
    set(gca,'XTick',x,'XTickLabel',{'Control','Migraine'});
    ylabel('$\Delta \sigma_{\mathrm{\it{test}}}$', ...
        'Interpreter', 'latex', 'FontSize', 45);
    % title('Light-Level Interaction on Sigma Test');

    box off;
    ylim padded;
end

%% Plotting the F values from fitting the migraine and control subjects
% Using the entire sets of nSubj x 4 F values, from migrainers and controls
if options.fVal
    % Flatten the 4D matrices into 1D vectors
    fValsMigraine = migraineFits.fValMatrix(:);
    fValsControl  = controlFits.fValMatrix(:);

    % Define shared bin edges
    % Use combined data to ensure both histograms share the same scale
    allData = [fValsMigraine; fValsControl];
    edges = linspace(min(allData), max(allData), 20);

    % Overlaid histogram so fancy so pretty
    figure; hold on;
    h1 = histogram(fValsMigraine, edges, 'FaceAlpha', 0.5, 'EdgeColor', 'none');
    h2 = histogram(fValsControl,  edges, 'FaceAlpha', 0.5, 'EdgeColor', 'none');

    xlabel('Negative log-likelihood (fVal)');
    ylabel('Count');
    legend({'Migrainers', 'Controls'});
    title('Model fit quality across groups');
    box off;

    % ---------now plot fVal by condition-------
    for l = 1:2
        f = figure('Color', 'w', 'Name', ['Light Level ' num2str(l)]);
        hold on;

        % Store handles for the legend
        hHandles = [];
        hNames   = {};

        % Loop through Contrasts (1 = Low, 2 = High)
        for c = 1:2
            % Calculate Means and SEMs
            mMeanfVal = squeeze(mean(migraineFits.fValMatrix(:,c,l,:), 1));
            mSEMfVal = squeeze(std(migraineFits.fValMatrix(:,c,l,:), [], 1)) / sqrt(nSubjM);
            cMeanfVal = squeeze(mean(controlFits.fValMatrix(:,c,l,:), 1));
            cSEMfVal  = squeeze(std(controlFits.fValMatrix(:,c,l,:), [], 1)) / sqrt(nSubjC);

            % Styling Logic
            % c=1: Low Contrast (White Fill, Dashed)
            % c=2: High Contrast (Color Fill, Solid)
            if c == 1
                fColM = [1 1 1]; fColC = [1 1 1]; lStyle = '--';
                cName = 'Low Contrast';
            else
                fColM = colMigraine; fColC = colControl; lStyle = '-';
                cName = 'High Contrast';
            end

            % Plot Migraine
            hM = errorbar(refFreqHz, mMeanfVal, mSEMfVal, ['o' lStyle], 'Color', colMigraine, ...
                'MarkerFaceColor', fColM, 'LineWidth', 1.5, 'MarkerSize', 7);

            % Plot Control
            hC = errorbar(refFreqHz, cMeanfVal, cSEMfVal, ['o' lStyle], 'Color', colControl, ...
                'MarkerFaceColor', fColC, 'LineWidth', 1.5, 'MarkerSize', 7);

            % Add to legend lists
            hHandles = [hHandles, hM, hC];
            hNames   = [hNames, {['Migraine (' cName ')'], ['Control (' cName ')']}];
        end

        % Styling
        xlabel('Reference Frequency (Hz)');
        ylabel('Negative log-likelihood (fVal)');
        title(['Light Level: ' char(if_then(l==1, "Low", "High"))]);
        xlim([min(refFreqHz)*0.9, max(refFreqHz)*1.1]);
        box off;
        grid on;
        set(gca, 'XScale', 'log');

        % Add Legend
        legend(hHandles, hNames, 'Location', 'northeast', 'Box', 'off');

        % --- Add Grey Background (Only for Low Light, l=1) ---
        if l == 1
            xl = xlim; yl = ylim;
            p = patch([xl(1) xl(2) xl(2) xl(1)], [yl(1) yl(1) yl(2) yl(2)], ...
                [0.9 0.9 0.9], 'EdgeColor', 'none', 'FaceAlpha', 0.5, 'Clipping', 'off');
            uistack(p, 'bottom'); % Ensure it stays behind the data
        end
    end

    %----------And now by frequency (avg across contrast and light level)--
    meanMigfValAll = squeeze(mean(mean(mean(migraineFits.fValMatrix, 1),2),3));
    migstdValAll = std(migraineFits.fValMatrix, 0, [1 2 3]);
    migSEMValAll = squeeze(migstdValAll/ sqrt(nSubjM));
    meanContfValAll = squeeze(mean(mean(mean(controlFits.fValMatrix, 1),2),3));
    contstdValAll = std(controlFits.fValMatrix, 0, [1 2 3]);
    contSEMValAll = squeeze(contstdValAll/ sqrt(nSubjC));

    figure('Color','w'); hold on;

    % Migraine
    errorbar(refFreqHz, meanMigfValAll, migSEMValAll, '-o', ...
        'Color', colMigraine, 'MarkerFaceColor', colMigraine, 'LineWidth', 1.5, 'MarkerSize', 7, 'DisplayName','Migraine');
    % Control
    errorbar(refFreqHz, meanContfValAll, contSEMValAll, '-s', ...
        'Color', colControl, 'MarkerFaceColor', colControl, 'LineWidth', 1.5, 'MarkerSize', 7, 'DisplayName','Control');

    set(gca,'XScale','log');
    xlabel('Reference Frequency (Hz)'); ylabel('Negative log-likelihood (fVal)');
    title('Frequency vs Sigma Test');
    legend('Location','northwest'); grid on; box off;
    xlim([min(refFreqHz)*0.9, max(refFreqHz)*1.1]);

end
%% Omnibus ANOVAS for sigma test and sigma ref
if options.anova
    % -------sigma test ------------------
    % Concatenate data
    sigmaTestAll = cat(1, sigmaTestM, sigmaTestC);
    sigmaRefAll  = cat(1, sigmaRefM, sigmaRefC);

    [nS, nC, nL, nF] = size(sigmaTestAll); % Dimensions: Subjects, Contrasts, Light, Freqs

    % Create Factor Indices
    % Use ndgrid to create a coordinate grid for the 4 data dimensions
    [S_idx, C_idx, L_idx, F_idx] = ndgrid(1:nS, 1:nC, 1:nL, 1:nF);
 
    % Create Group Vector (1 = Migraine, 2 = Control)
    nMigraine = size(sigmaTestM, 1);
    G_idx = ones(nS, nC, nL, nF);
    G_idx((nMigraine+1):end, :, :, :) = 2;

    % Set up Nesting and Random Factors
    % Factors: {Subject, Group, Contrast, Light, Frequency}
    % Subject (1) is nested within Group (2)
    nest = zeros(5, 5);
    nest(1, 2) = 1;

    % Prepare the inputs for anovan
    factors = {S_idx(:), G_idx(:), C_idx(:), L_idx(:), F_idx(:)};
    varnames = {'Subject', 'Group', 'Contrast', 'LightLevel', 'Frequency'};

    % Run ANOVA
    % Note: 'full' model with 5 factors can be very large.
    % If it crashes or takes too long, change 'model' to 'interaction'
    % to exclude 4-way/5-way interactions.
    fprintf('Running ANOVA for Sigma Test...\n');
    [p, tbl, stats] = anovan(sigmaTestAll(:), factors, ...
        'nested', nest, ...
        'random', 1, ... % Subject is random
        'model', 3, ...   % up to 3 way interactions
        'varnames', varnames);

    fprintf('\nRunning ANOVA for Sigma Ref...\n');
    [pZero, tblZero, statsZero] = anovan(sigmaRefAll(:), factors, ...
        'nested', nest, ...
        'random', 1, ...
        'model', 3, ...    % up to 3 way interactions
        'varnames', varnames);

    % 5. Create a table for visualization
    G_labels = {'Migraine', 'Control'};
    C_labels = {'Low', 'High'};
    L_labels = {'Low', 'High'};
    F_labels = {'Freq1', 'Freq2', 'Freq3', 'Freq4', 'Freq5'}; % Update to your labels

    % Display Means
    T_sigma = table(G_idx(:), C_idx(:), L_idx(:), F_idx(:), sigmaTestAll(:), ...
        'VariableNames', {'Group', 'Contrast', 'Light', 'Freq', 'Sigma'});
    % Group by all factors
    grpstats(T_sigma, {'Group', 'Contrast', 'Light', 'Freq'}, 'mean')

%Flatten Data
% Combine all conditions for Sigma Test
testM = sigmaTestM(:);
testC = sigmaTestC(:);

% Combine all conditions for Sigma Ref 
refM  = sigmaRefM(:);
refC  = sigmaRefC(:);

% --- Define Shared Bin Edges ---
allTest = [testM; testC];
allRef  = [refM; refC];
testEdges = linspace(min(allTest), max(allTest), 40);
refEdges  = linspace(min(allRef), max(allRef), 40);

% Plot
figure('Color', 'w', 'Position', [100 100 900 400]);
t = tiledlayout(1, 2, 'TileSpacing', 'compact');

% Panel 1: Sigma Test
nexttile; hold on;
histogram(testM, testEdges, 'FaceColor', [0.8 0.3 0.3], 'FaceAlpha', 0.4, 'EdgeColor', 'none');
histogram(testC, testEdges, 'FaceColor', [0.3 0.3 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none');
title('Distribution: Sigma Test');
xlabel('Sigma Value'); ylabel('Count');
legend({'Migraine', 'Control'}, 'Box', 'off');
box off; grid on;

% Panel 2: Sigma Ref
nexttile; hold on;
histogram(refM, refEdges, 'FaceColor', [0.8 0.3 0.3], 'FaceAlpha', 0.4, 'EdgeColor', 'none');
histogram(refC, refEdges, 'FaceColor', [0.3 0.3 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none');
title('Distribution: Sigma Ref');
xlabel('Sigma Value'); ylabel('Count');
xlim([0 5]); % to match sigma test
if options.superSubj
    ylim([0 5]);
else
    ylim([0 40]);
end
legend({'Migraine', 'Control'}, 'Box', 'off');
box off; grid on;

end

end

% Helper function for title logic
function out = if_then(cond, a, b)
if cond, out = a; else, out = b; end
end