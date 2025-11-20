% SETUP
% Defining the directory
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir = 'FLIC_data';
projectName = 'combiLED';
experimentName = 'DCPT_SDT';

% Define subjects + parameters
% List of possible control subject IDs: {'FLIC_0013', 'FLIC_0015', 'FLIC_0017', ...
% 'FLIC_0018', 'FLIC_0019','FLIC_0020', 'FLIC_0021', 'FLIC_0022', 'FLIC_0027', 'FLIC_0039', 'FLIC_0042'};
subjectID = {'FLIC_0013', 'FLIC_0015', 'FLIC_0017','FLIC_0018', ...
    'FLIC_0019','FLIC_0020', 'FLIC_0021', 'FLIC_0022', 'FLIC_0027', 'FLIC_0028', ...
    'FLIC_0039', 'FLIC_0042'};
modDirection = 'LightFlux';
NDLabel = {'3x0', '0x5'};   % {'3x0', '0x5'}
stimParamLabels = {'low', 'hi'}; % {'low', 'hi'}
refFreqHz = logspace(log10(10),log10(30),5);  % logspace(log10(10),log10(30),5)
targetPhotoContrast = {'0x1','0x3'};  % {'0x1','0x3'}

% Define length variables
nFreqs = length(refFreqHz);
nContrasts = length(targetPhotoContrast);
nLightLevels = length(NDLabel); 
nSubj = length(subjectID);

% Initialize matrices of params
% nSubj x 2 x 2 x 5, subj x nContrasts x nLightLevels x nFreqs
sigmaMatrix = zeros(nSubj,nContrasts,nLightLevels,nFreqs);
critBaselineMatrix = zeros(nSubj,nContrasts,nLightLevels,nFreqs);

%% FITTING CODE %%

for subjIdx = 1:nSubj

    thisSubj = subjectID{subjIdx};

    % Create layouts, one per contrast
    figLow = figure;
    tLowContrast = tiledlayout(figLow, nLightLevels, nFreqs, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tLowContrast, ['Low contrast psychometric functions for ' thisSubj], 'FontWeight', 'bold');
    figuresize(1000, 300, 'units', 'pt');

    figHigh = figure;
    tHighContrast = tiledlayout(figHigh, nLightLevels, nFreqs, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tHighContrast, ['High contrast psychometric functions for ' thisSubj], 'FontWeight', 'bold');
    figuresize(1000, 300, 'units', 'pt');

    for lightIdx = 1:nLightLevels

        for refFreqIdx = 1:nFreqs
            currentRefFreq = refFreqHz(refFreqIdx);

            for contrastIdx = 1:nContrasts

                % Pick the correct layout
                if contrastIdx == 1
                    % Low contrast
                    nexttile(tLowContrast);
                else
                    % High contrast
                    nexttile(tHighContrast);
                end
                hold on;

                % Combined trial data for one subj over high and low sides
                comboTrialData = [];
                % Reset lists
                probData = [];
                nTrials = [];
                nTrialsPlot = [];

                for sideIdx = 1:length(stimParamLabels)

                    % Build path to the data file
                    subjectDir = fullfile(dropBoxBaseDir, dropBoxSubDir, projectName, thisSubj);
                    dataDir = fullfile(subjectDir, [modDirection '_ND' NDLabel{lightIdx} '_shifted'], experimentName);

                    fileName = fullfile(dataDir, ...
                        [thisSubj '_' modDirection '_' experimentName ...
                        '_cont-' targetPhotoContrast{contrastIdx} '_refFreq-' num2str(currentRefFreq) 'Hz_' stimParamLabels{sideIdx} '.mat']);

                    if exist(fileName, 'file')
                        load(fileName, 'psychObj');

                        thisTrialData = psychObj.questData.trialData;

                        % Flip the sign for the low side values
                        if contains(fileName, 'lo')
                            for trial = 1:numel(thisTrialData)
                                thisTrialData(trial).stim = -thisTrialData(trial).stim;
                            end
                        end

                        % Append to combined trial data
                        comboTrialData = [comboTrialData; thisTrialData];

                        % Store one psychObj as template if needed
                        if refFreqIdx == 1 && sideIdx == 1
                            templatePsychObj = psychObj;
                        end
                    else
                        warning('File not found: %s', fileName);
                    end

                end % sideIdx

                % FIRST, plot the data for this ref freq
                stimCounts = qpCounts(qpData(comboTrialData), templatePsychObj.questData.nOutcomes);
                stim = zeros(length(stimCounts), templatePsychObj.questData.nStimParams);
                pRespondDifferent = zeros(1,length(stimCounts));
                nTrialsPlot = zeros(1,length(stimCounts));

                for cc = 1:length(stimCounts)
                    stim(cc) = stimCounts(cc).stim;
                    nTrialsPlot(cc) = sum(stimCounts(cc).outcomeCounts);
                    pRespondDifferent(cc) = stimCounts(cc).outcomeCounts(2)/nTrialsPlot(cc);
                end

                % Determine marker sizes based on number of trials
                markerSizeIdx = discretize(nTrialsPlot(2:end),3); % divide into 3 bins
                markerSizeIdx = [3 markerSizeIdx]; % keep first point as largest
                markerSizeSet = [25, 50, 100];

                % Plot the points
                for cc = 1:length(stimCounts)
                    if stim(cc) == 0  % make the 0 dB case a different shape
                        markerShape = 'diamond';
                    else
                        markerShape = 'o';
                    end

                    scatter(stim(cc), pRespondDifferent(cc), markerSizeSet(markerSizeIdx(cc)), ...
                        'MarkerFaceColor', [pRespondDifferent(cc) 0 1-pRespondDifferent(cc)], ...
                        'MarkerEdgeColor','k', ...
                        'MarkerFaceAlpha', nTrialsPlot(cc)/max(nTrialsPlot), ...
                        'Marker', markerShape);
                    hold on;
                end

                % SECOND, load data. Compute unique dB values and prob data for this ref freq
                dB_data = [comboTrialData.stim];
                response_data = [comboTrialData.respondYes];
                uniqueDbValues = unique(dB_data);

                % Calculate observed proportion “different” per stim level
                for ii = 1:length(uniqueDbValues)
                    probData(ii) = mean(response_data(dB_data==uniqueDbValues(ii)));
                    nTrials(ii) = sum(dB_data == uniqueDbValues(ii)); % nTrials at each dB
                end

                epsilon = 0.01; % Define the constant lapse rate value

                % Fit the psychometric function
                % initial_params = [m, x_limit, crit_baseline, sigma]
                initial_params = [0,1,2,0.5];

                options = bads('defaults');
                options.MaxIter = 50;
                options.MaxFunEvals = 500;
                lb = [0,1,0,0.001]; ub = [0,1,5,3];
                fit = bads(@(p) negLogLikelihood(p,uniqueDbValues,probData,nTrials,epsilon), ...
                    initial_params, lb, ub, lb, ub, [], options);

                % Add the crit_baseline and sigma values to the matrix
                sigmaMatrix(subjIdx, contrastIdx,lightIdx,refFreqIdx) = fit(4);
                critBaselineMatrix(subjIdx, contrastIdx,lightIdx,refFreqIdx) = fit(3);

                % Plot the fit for this ref frequency
                hold on;

                x = -5:0.1:5;  % evaluate the model at more dB values
                plot(x, modifiedSameDiffModel(x,fit,epsilon), 'k-', 'LineWidth',2);

                xlabel('stimulus difference [dB]');
                if lightIdx == 1 && refFreqIdx == 1
                    ylabel({'LOW', 'proportion respond different'});
                end
                if lightIdx == 2 && refFreqIdx == 1
                    ylabel({'HIGH', 'proportion respond different'});
                end
                title(sprintf('Ref freq = %.1f Hz', currentRefFreq));
                ylim([-0.1 1.1]);
                xlim([-6.0 6.0]);


            end
        end

    end

end

%% Code to plot sigma and criterion across 20 conditions

sigmaHandle = figure;
hold on;
critHandle = figure;
hold on;

lightLevelPts = {'ob','sr',};
contrastPts = {'b', 'r'; 'w', 'w'};

for lightIdx = 1:nLightLevels
    for contrastIdx = 1:nContrasts

        figure(sigmaHandle);
        plot(refFreqHz, squeeze(sigmaMatrix(contrastIdx,lightIdx,:)), lightLevelPts{lightIdx}, ...
            'MarkerFaceColor', contrastPts{contrastIdx, lightIdx}, 'MarkerSize', 12);
        title(['Sigma Values for ' thisSubj]);
        xlim([8 35]); xscale log
        ylim([0 3.5]);

        figure(critHandle);
        plot(refFreqHz, squeeze(critBaselineMatrix(contrastIdx,lightIdx,:)), lightLevelPts{lightIdx}, ...
            'MarkerFaceColor', contrastPts{contrastIdx, lightIdx}, 'MarkerSize', 12);
        title(['Criterion Values for ' thisSubj]);
        xlim([8 35]); xscale log
        ylim([0 3.5]);

    end
end
% Add legend
figure(sigmaHandle); 
legend({'Low contrast, low light','High contrast, low light',...
        'Low contrast, high light','High contrast, high light'}, ...
        'Location','best');

figure(critHandle);
legend({'Low contrast, low light','High contrast, low light',...
        'Low contrast, high light','High contrast, high light'}, ...
        'Location','best');

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
title('Sigma parameter across reference frequencies', 'FontWeight', 'bold');
xlabel('Reference frequency [Hz]', 'Position',[mean(xlim), 0.3, 0]);
ylabel('Sigma parameter', 'Position',[-0.25, mean(ylim), 0]);
xticks(xPositions);
xticklabels(refFreqHz);
hold(ax, 'off');

%% Plotting the false alarm rate at each ref freq for each subj
% also collapsed across light level and contrast level

% Pre-allocate falseAlarmsMatrix
falseAlarmsMatrix = zeros(nSubj, nContrasts, nLightLevels, nFreqs);

% Loading files and extracting the data 
for subjIdx = 1:nSubj
    thisSubj = subjectID{subjIdx};

    for lightIdx = 1:nLightLevels
        for refFreqIdx = 1:nFreqs
            currentRefFreq = refFreqHz(refFreqIdx);

            for contrastIdx = 1:nContrasts

                comboTrialData = [];

                for sideIdx = 1:length(stimParamLabels)
                    % Build path to the data file
                    subjectDir = fullfile(dropBoxBaseDir, dropBoxSubDir, projectName, thisSubj);
                    dataDir = fullfile(subjectDir, [modDirection '_ND' NDLabel{lightIdx} '_shifted'], experimentName);

                    fileName = fullfile(dataDir, ...
                        [thisSubj '_' modDirection '_' experimentName ...
                        '_cont-' targetPhotoContrast{contrastIdx} '_refFreq-' num2str(currentRefFreq) 'Hz_' stimParamLabels{sideIdx} '.mat']);

                    if exist(fileName, 'file')
                        load(fileName, 'psychObj');
                        thisTrialData = psychObj.questData.trialData;

                        % Flip sign for low side if needed
                        if contains(fileName, 'lo')
                            for trial = 1:numel(thisTrialData)
                                thisTrialData(trial).stim = -thisTrialData(trial).stim;
                            end
                        end

                        comboTrialData = [comboTrialData; thisTrialData];
                    else
                        warning('File not found: %s', fileName);
                    end
                end % sideIdx

                if ~isempty(comboTrialData)  % Have trial data combined across sides

                    % Load stim and response data
                    dB_data = [comboTrialData.stim];
                    response_data = [comboTrialData.respondYes];
                    uniqueDbValues = unique(dB_data);

                    % Compute proportion "respond different" per stim level
                    for ii = 1:length(uniqueDbValues)
                        probData(ii) = mean(response_data(dB_data==uniqueDbValues(ii)));
                    end

                    % Extract false alarm rate (proportion "respond diff" at 0 dB)
                    zeroIdx = find(uniqueDbValues == 0);
                    falseAlarmsMatrix(subjIdx, contrastIdx, lightIdx, refFreqIdx) = probData(zeroIdx);
                end

            end
        end
    end
end

% Collapsing across dims
meanContrastFA = mean(falseAlarmsMatrix, 2);  % average over contrast (dim 2)
avgFAParticipant = mean(meanContrastFA, 3); % average over light (dim 3)
plotData = squeeze(avgFAParticipant);    % remove singleton dims

subjData = cell(1, nFreqs);
for k = 1:nFreqs
    subjData{k} = plotData(:, k);
end

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
    set(H{1}(h), 'Marker', 's', ...
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
    '-ks', ...                 
    'MarkerFaceColor', 'k', ...
    'MarkerSize', 10, ...
    'LineWidth', 1.5);

% Title and labels
title('False alarm rates across reference frequencies', 'FontWeight', 'bold');
xlabel('Reference frequency [Hz]');
ylabel('False alarm rate');
xticks(xPositions);
xticklabels(refFreqHz);

hold(ax, 'off');

%% Objective function %%%

function nll = negLogLikelihood(params, uniqueDbValues, probData, nTrials, epsilon)

    % Predict probability of "different" at each unique dB level
    P_diff = modifiedSameDiffModel(uniqueDbValues, params, epsilon);
    % P_diff = max(min(P_diff, 1 - 1e-9), 1e-9); % To make sure 0 < P_diff < 1

    % Finding the count of different responses (aka the number of
    % "successes")
    k = probData .* nTrials; % prop observed diff multiplied by total number of trials at that dB
    
    % Finding the binomial negative log-likelihood
    nll = -sum(k .* log(P_diff) + (nTrials - k) .* log(1 - P_diff));

end

