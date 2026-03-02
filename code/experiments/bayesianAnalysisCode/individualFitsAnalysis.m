function output = individualFitsAnalysis(options)
% Define the arguments block
arguments
    options.barPlot (1,1) logical = true
    options.fVal (1,1) logical = true
    options.anova (1,1) logical = true
end

%% load data
%set up paths
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir = 'FLIC_analysis';
projectName = 'dichopticFlicker';
experimentName = 'sigmaData';

dataDir = fullfile(dropBoxBaseDir, dropBoxSubDir, projectName, experimentName);
migraineFilePath = fullfile(dataDir, '15Migrainer_individualSigmaFits.mat');
controlFilePath  = fullfile(dataDir, '15Control_individualSigmaFits.mat');
%load
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

% define labels
contrastLabels = {'lo', 'hi'};
NDLabel = {'3.0', '0.5'};


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
refFreqHz   = migraineFits.refFreqHz;

% Loop through light levels (1 = Low, 2 = High)
for l = 1:2
    f = figure('Color', 'w', 'Name', ['Light Level ' num2str(l)]);
    hold on;

    % Store handles for the legend
    hHandles = [];
    hNames   = {};

    % Loop through Contrasts (1 = Low, 2 = High)
    for c = 1:2
        % Calculate Means and SEMs
        mMean = squeeze(mean(migraineFits.sigmaTestMatrix(:,c,l,:), 1));
        mSEM  = squeeze(std(migraineFits.sigmaTestMatrix(:,c,l,:), [], 1)) / sqrt(15);
        cMean = squeeze(mean(controlFits.sigmaTestMatrix(:,c,l,:), 1));
        cSEM  = squeeze(std(controlFits.sigmaTestMatrix(:,c,l,:), [], 1)) / sqrt(15);

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
    ylabel('Sigma Test');
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

% again for sigma ref

% Loop through light levels (1 = Low, 2 = High)
for l = 1:2
    f = figure('Color', 'w', 'Name', ['Light Level ' num2str(l)]);
    hold on;

    % Store handles for the legend
    hHandles = [];
    hNames   = {};

    % Loop through Contrasts (1 = Low, 2 = High)
    for c = 1:2
        % Calculate Means and SEMs
        mMean = squeeze(mean(migraineFits.sigmaRefMatrix(:,c,l,:), 1));
        mSEM  = squeeze(std(migraineFits.sigmaRefMatrix(:,c,l,:), [], 1)) / sqrt(15);
        cMean = squeeze(mean(controlFits.sigmaRefMatrix(:,c,l,:), 1));
        cSEM  = squeeze(std(controlFits.sigmaRefMatrix(:,c,l,:), [], 1)) / sqrt(15);

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

%% Bar plot: Plotting sigma parameters for each contrast x light level condition
if options.barPlot
    %Prepare Data
    barData = [muSigmaTestC(:), muSigmaTestM(:)];
    errData = [semSigmaTestC(:), semSigmaTestM(:)];

    % Initialize Figure
    figure('Color', 'w');
    hold on;

    % Darkness Patch
    % Spans x=0.5 to 2.5 (covering the first 2 groups: Low Light)
    patch([0.5, 2.5, 2.5, 0.5], [0, 0, 2.5, 2.5], [0.9 0.9 0.9], ...
        'EdgeColor', 'none', 'FaceAlpha', 0.5);

    % Plot Bars
    b = bar(barData, 'grouped');
    b(1).FaceColor = [0.3 0.3 0.8]; % Control
    b(2).FaceColor = [0.8 0.3 0.3]; % Migraine

    % Error Bars
    for i = 1:numel(b)
        errorbar(b(i).XEndPoints, b(i).YData, errData(:,i), ...
            'k', 'linestyle', 'none', 'LineWidth', 1.5);
    end

    % Formatting & Labels
    set(gca, 'Layer', 'top', 'Box', 'off');
    ylabel('Sigma Test');
    ylim([0 2.5]);
    xlim([0.5, 4.5]);
    xticks([]); % Turn off default ticks to make room for custom labels
    legend([b(1), b(2)], {'Control', 'Migraine'}, 'Location', 'Northwest');
    title('Sigma Test by Contrast × Light');

    % "Contrast" Labels (Centered between the two bars) ---
    contrastNames = {'Low Contrast', 'High Contrast', 'Low Contrast', 'High Contrast'};
    yContrast = -0.15;
    for i = 1:4
        % Calculate the midpoint between the Control and Migraine bars
        midPoint = (b(1).XEndPoints(i) + b(2).XEndPoints(i)) / 2;
        text(midPoint, yContrast, contrastNames{i}, ...
            'HorizontalAlignment', 'center', 'FontSize', 9, 'Rotation', 0);
    end

    % "Light" Labels (Across bars) ---
    yLight = -0.45; % Lower down to avoid collision
    text(1.5, yLight, 'Low Light', 'HorizontalAlignment', 'center', ...
        'FontWeight', 'bold', 'FontSize', 11, 'Clipping', 'off');
    text(3.5, yLight, 'High Light', 'HorizontalAlignment', 'center', ...
        'FontWeight', 'bold', 'FontSize', 11, 'Clipping', 'off');

    % Expand the bottom margin (the 0.3) so labels aren't cut off
    set(gca, 'Position', [0.15 0.3 0.75 0.6]);

    %------ Plot sigma ref bar plot----

    %Prepare Data
    barData = [muSigmaRefC(:), muSigmaRefM(:)];
    errData = [semSigmaRefC(:), semSigmaRefM(:)];

    % Initialize Figure
    figure('Color', 'w');
    hold on;

    % Darkness Patch
    % Spans x=0.5 to 2.5 (covering the first 2 groups: Low Light)
    patch([0.5, 2.5, 2.5, 0.5], [0, 0, 2.5, 2.5], [0.9 0.9 0.9], ...
        'EdgeColor', 'none', 'FaceAlpha', 0.5);

    % Plot Bars
    b = bar(barData, 'grouped');
    b(1).FaceColor = [0.3 0.3 0.8]; % Control
    b(2).FaceColor = [0.8 0.3 0.3]; % Migraine

    % Error Bars
    for i = 1:numel(b)
        errorbar(b(i).XEndPoints, b(i).YData, errData(:,i), ...
            'k', 'linestyle', 'none', 'LineWidth', 1.5);
    end

    % Formatting & Labels
    set(gca, 'Layer', 'top', 'Box', 'off');
    ylabel('Sigma Ref');
    ylim([0 2.5]);
    xlim([0.5, 4.5]);
    xticks([]); % Turn off default ticks to make room for custom labels
    legend([b(1), b(2)], {'Control', 'Migraine'}, 'Location', 'Northwest');
    title('Sigma Ref by Contrast × Light');

    % "Contrast" Labels (Centered between the two bars) ---
    contrastNames = {'Low Contrast', 'High Contrast', 'Low Contrast', 'High Contrast'};
    yContrast = -0.15;
    for i = 1:4
        % Calculate the midpoint between the Control and Migraine bars
        midPoint = (b(1).XEndPoints(i) + b(2).XEndPoints(i)) / 2;
        text(midPoint, yContrast, contrastNames{i}, ...
            'HorizontalAlignment', 'center', 'FontSize', 9, 'Rotation', 0);
    end

    % "Light" Labels (Across bars) ---
    yLight = -0.45; % Lower down to avoid collision
    text(1.5, yLight, 'Low Light', 'HorizontalAlignment', 'center', ...
        'FontWeight', 'bold', 'FontSize', 11, 'Clipping', 'off');
    text(3.5, yLight, 'High Light', 'HorizontalAlignment', 'center', ...
        'FontWeight', 'bold', 'FontSize', 11, 'Clipping', 'off');

    % Expand the bottom margin (the 0.3) so labels aren't cut off
    set(gca, 'Position', [0.15 0.3 0.75 0.6]);
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
end
%% Omnibus ANOVAS for sigma test and sigma ref
if options.anova
    % -------sigma test ------------------
    % Concatenate data
    sigmaTestAll = cat(1, migraineFits.sigmaTestMatrix, controlFits.sigmaTestMatrix);
    sigmaRefAll  = cat(1, migraineFits.sigmaRefMatrix, controlFits.sigmaRefMatrix);

    [nS, nC, nL, nF] = size(sigmaTestAll); % Dimensions: Subjects, Contrasts, Light, Freqs

    % Create Factor Indices
    % Use ndgrid to create a coordinate grid for the 4 data dimensions
    [S_idx, C_idx, L_idx, F_idx] = ndgrid(1:nS, 1:nC, 1:nL, 1:nF);

    % Create Group Vector (1 = Migraine, 2 = Control)
    nMigraine = size(migraineFits.sigmaTestMatrix, 1);
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
        'model', 'full', ...
        'varnames', varnames);

    fprintf('\nRunning ANOVA for Sigma Ref...\n');
    [pZero, tblZero, statsZero] = anovan(sigmaRefAll(:), factors, ...
        'nested', nest, ...
        'random', 1, ...
        'model', 'full', ...
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
end
end

% Helper function for title logic
function out = if_then(cond, a, b)
if cond, out = a; else, out = b; end
end