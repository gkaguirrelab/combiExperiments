%% Plotting sigma values at each ref freq
% collapsed across light level and contrast level

% Average across contrast (dim 2) and light level (dim 3)
sigmaSubjFreq = squeeze(mean(mean(sigmaMatrix1, 2), 3));  % [Subj × Freq]
sigmaZeroSubjFreq = squeeze(mean(mean(sigmaMatrix2, 2), 3));

sigmaMean = mean(sigmaSubjFreq, 1);                      
sigmaSEM  = std(sigmaSubjFreq, [], 1) ./ sqrt(nSubj);    

sigmaZeroMean = mean(sigmaZeroSubjFreq, 1);                      
sigmaZeroSEM  = std(sigmaZeroSubjFreq, [], 1) ./ sqrt(nSubj);  

xPositions = 1:nFreqs;

figure; hold on;

% Sigma
errorbar(xPositions, sigmaMean, sigmaSEM, ...
    '-o', ...
    'Color', [0 0 0], ...
    'MarkerFaceColor', [0 0 0], ...
    'LineWidth', 1.8, ...
    'MarkerSize', 8);

% Sigma zero
errorbar(xPositions, sigmaZeroMean, sigmaZeroSEM, ...
    '-o', ...
    'Color', [0.2 0.4 0.8], ...
    'MarkerFaceColor', [0.2 0.4 0.8], ...
    'LineWidth', 1.8, ...
    'MarkerSize', 8);

% Axes & labels
title('MIGRAINERS: Bayesian sigma parameters across reference frequencies', ...
    'FontWeight', 'bold');
xlabel('Reference frequency [Hz]');
ylabel('Sigma parameter');
xlim([0.5, nFreqs + 0.5])

xticks(xPositions);
xticklabels(refFreqHz);
ylim([0 3]);

legend({'\sigma (different trials)', '\sigma_0 (same trials)'}, ...
    'Location', 'best');

box off;
hold off;

%% Set up & plotting sigma values at each ref freq for each subj
% collapsed across light level level ONLY

% Average across light level (Dimension 3 of the matrix)
% The result will be [Subj, Contrast, 1, Freq]
% Then squeeze to remove the singleton dimension
avgSigmaParticipant = squeeze(mean(sigmaMatrix, 3));

% Prepare plot parameters
colors = lines(nSubj); % one color per subject
catIdxFlat = repmat((1:nSubj)', nFreqs, 1); % identifies 1 to nSubj
xPositions = 1:nFreqs;

% Loop over contrast conditions (1 = low, 2 = high)
contrastNames = {'Low contrast', 'High contrast'};

for contrastIdx = 1:length(contrastNames)

    % Extract the slice for this contrast
    data2D = squeeze(avgSigmaParticipant(:,contrastIdx,:)); % [nSubj × nFreqs]

    % Pre-allocate a 1 × nFreqs cell array
    subjData = cell(1, nFreqs);

    % Each cell should contain a 5×1 vector (all subjects at this frequency)
    for k = 1:nFreqs
        subjData{k} = data2D(:, k);   % 5×1
    end

    % PLOT
    fig = figure;
    ax = axes(fig);
    hold(ax, 'on');
    H = plotSpread(subjData, ...
        'xValues', xPositions, ...
        'binWidth', 0.2, ...
        'categoryIdx', catIdxFlat, ...
        'categoryColors', colors);

    % Customizing the marker
    for h = 1:numel(H{1})
        c = get(H{1}(h), 'Color');  % get the current line color
        cFaint = c + (1 - c)*0.5;   % blend 70% with white
        set(H{1}(h), 'Marker', 'o', ...
            'MarkerSize', 8, ...
            'MarkerFaceColor', cFaint, ...
            'MarkerEdgeColor', cFaint);
    end

    % Connecting the points for each subject
    % Extract the XY positions from plotSpread output
    xy = get(H{1}, 'XData');
    yy = get(H{1}, 'YData');

    allX = cell2mat(xy(:)');
    allY = cell2mat(yy(:)');
    % plotSpread reorders by categoryIdx. so now indices 1-5 are subj1,
    % indices 6-10 are subj2, and so on.

    for s = 1:nSubj
        idx = (s-1)*nFreqs + (1:nFreqs);

        % draw line
        h = plot(allX(idx), allY(idx), '-', ...
            'Color', colors(s,:), ...
            'LineWidth', 1, ...
            'MarkerSize', 6, ...
            'MarkerFaceColor', colors(s,:));

        h.Color(4) = 0.2; % make the lines more transparent
    end

    % Compute mean and standard error across subjects for each frequency
    for k = 1:nFreqs
        thisFreq = subjData{k};
        meanValues(k) = mean(thisFreq);  % mean across subjects for this frequency
        semValues(k)  = std(thisFreq) / sqrt(nSubj);  % SEM
    end
    hMean = errorbar(xPositions, meanValues, semValues, ...
        '-ko', ...
        'MarkerFaceColor', 'k', ...
        'MarkerSize', 10, ...
        'LineWidth', 1.5);

    % Add title and axis labels
    title(['CONTROLS: ' contrastNames{contrastIdx} ' Bayesian sigma across frequency' ], 'FontWeight', 'bold');
    xlabel('Reference frequency [Hz]');
    ylabel('Sigma parameter', 'Position',[-0.25, mean(ylim), 0]);
    xticks(xPositions);
    xticklabels(refFreqHz);
    ylim([0 3])
    hold(ax, 'off');

end
%% Set up & plotting sigma values at each ref freq for each subj
% collapsed across contrast ONLY

% Average across contrast (Dimension 2 of the matrix)
% The result will be [Subj, 1, LightLevel, Freq]
% Then squeeze to remove the singleton dimension
avgSigmaParticipant = squeeze(mean(sigmaMatrix, 2));

% Prepare plot parameters
colors = lines(nSubj); % one color per subject
catIdxFlat = repmat((1:nSubj)', nFreqs, 1); % identifies 1 to nSubj
xPositions = 1:nFreqs;

% Loop over contrast conditions (1 = low, 2 = high)
lightNames = {'Low light', 'High light'};

for lightIdx = 1:length(lightNames)

    % Extract the slice for this light level
    data2D = squeeze(avgSigmaParticipant(:,lightIdx,:)); % [nSubj × nFreqs]

    % Pre-allocate a 1 × nFreqs cell array
    subjData = cell(1, nFreqs);

    % Each cell should contain a 5×1 vector (all subjects at this frequency)
    for k = 1:nFreqs
        subjData{k} = data2D(:, k);   % 5×1
    end

    % PLOT
    fig = figure;
    ax = axes(fig);
    hold(ax, 'on');
    H = plotSpread(subjData, ...
        'xValues', xPositions, ...
        'binWidth', 0.2, ...
        'categoryIdx', catIdxFlat, ...
        'categoryColors', colors);

    % Customizing the marker
    for h = 1:numel(H{1})
        c = get(H{1}(h), 'Color');  % get the current line color
        cFaint = c + (1 - c)*0.5;   % blend 70% with white
        set(H{1}(h), 'Marker', 'o', ...
            'MarkerSize', 8, ...
            'MarkerFaceColor', cFaint, ...
            'MarkerEdgeColor', cFaint);
    end

    % Connecting the points for each subject
    % Extract the XY positions from plotSpread output
    xy = get(H{1}, 'XData');
    yy = get(H{1}, 'YData');

    allX = cell2mat(xy(:)');
    allY = cell2mat(yy(:)');
    % plotSpread reorders by categoryIdx. so now indices 1-5 are subj1,
    % indices 6-10 are subj2, and so on.

    for s = 1:nSubj
        idx = (s-1)*nFreqs + (1:nFreqs);

        % draw line
        h = plot(allX(idx), allY(idx), '-', ...
            'Color', colors(s,:), ...
            'LineWidth', 1, ...
            'MarkerSize', 6, ...
            'MarkerFaceColor', colors(s,:));

        h.Color(4) = 0.2; % make the lines more transparent
    end

    % Compute mean and standard error across subjects for each frequency
    for k = 1:nFreqs
        thisFreq = subjData{k};
        meanValues(k) = mean(thisFreq);  % mean across subjects for this frequency
        semValues(k)  = std(thisFreq) / sqrt(nSubj);  % SEM
    end
    hMean = errorbar(xPositions, meanValues, semValues, ...
        '-ko', ...
        'MarkerFaceColor', 'k', ...
        'MarkerSize', 10, ...
        'LineWidth', 1.5);

    % Add title and axis labels
    title(['CONTROLS: ' lightNames{lightIdx} ' Bayesian sigma across frequency' ], 'FontWeight', 'bold');
    xlabel('Reference frequency [Hz]');
    ylabel('Sigma parameter', 'Position',[-0.25, mean(ylim), 0]);
    xticks(xPositions);
    xticklabels(refFreqHz);
    ylim([0 3])
    hold(ax, 'off');

end

%% False alarms??