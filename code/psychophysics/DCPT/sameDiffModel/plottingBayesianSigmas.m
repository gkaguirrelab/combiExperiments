%% Set up for plotting sigma values at each ref freq
% collapsed across light level and contrast level

% Average across Contrast (Dimension 2)
meanContrastSigma = mean(sigmaMatrix, 2);

% Average across light level (Dimension 3 of the matrix)
% The result will be [Subj, 1, 1, Freq]
avgSigmaParticipant = mean(meanContrastSigma, 3);

% Remove the singleton dimensions 
% The final matrix 'plotData' will have dimensions: [Subj, Freq]
plotData = squeeze(avgSigmaParticipant);

% Pre-allocate a cell array for plotSpread 
subjData = cell(1, nFreqs);

% Loop through each frequency point
for k = 1:nFreqs
    % Extract all participant data for the current frequency.
    % This is a vector of size [nSubj x 1]
    subjData{k} = plotData(:, k);
end

%% Plotting sigma values at each ref freq for each subj
% collapsed across light level and contrast level

% Create colors and categoryIdxs for plotSpread
% bg = {'w', 'k'}; % colors to avoid
% colors = distinguishable_colors(nSubj, bg); % setting a color for each subj
colors = lines(nSubj); % replace this with distinguishable colors ^^
catIdxFlat = repmat((1:nSubj)', nFreqs, 1); % identifies 1 to nSubj

xPositions = 1:nFreqs;

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
title('CONTROLS: Bayesian sigma parameter across reference frequencies', 'FontWeight', 'bold');
xlabel('Reference frequency [Hz]'); % 'Position',[mean(xlim), 0.3, 0]);
ylabel('Sigma parameter'); % 'Position',[-0.25, mean(ylim), 0]);
xticks(xPositions);
xticklabels(refFreqHz);
ylim([0 3]);
hold(ax, 'off');