function plotDCPT_SDT_rxnTime(subjectList, refFreqSetHz, modDirections, targetPhotoContrast, NDLabel, plotCorrectOnly)
% % Function to plot the high and low ends of a psychometric funciton on the
% % same graph.
% % e.g.,
%{
subjectList = {'FLIC_0015','FLIC_0017','FLIC_0018','FLIC_0021'};
refFreqSetHz = logspace(log10(10),log10(30),5);
modDirections = {'LightFlux'};
targetPhotoContrast = [0.10; 0.30];  % [Low contrast levels; high contrast levels]
% Light Flux is [0.10; 0.30]
NDLabel = {'3x0', '0x5'};
plotDCPT_SDT_rxnTime(subjectList, refFreqSetHz, modDirections, targetPhotoContrast, NDLabel);
%}

if nargin < 6
    plotCorrectOnly = true;
end

dropBoxBaseDir=getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir='FLIC_data';
projectName='combiLED';
experimentName = 'DCPT_SDT';
% Set the labels for the high and low stimulus ranges
stimParamLabels = {'low', 'hi'};
lightLevelLabels = {'Low Light', 'High Light'}; % to be used only for the title
% Set number of contrast levels and sides
nContrasts = 2;
nSides = 2;
% Define the modulation and data directories
subjectDir = fullfile(...
    dropBoxBaseDir,...
    dropBoxSubDir,...
    projectName);

% --- Pass 1: Load all data and determine global axis limits ---
all_rxnTimes = [];
all_stimdB = [];
subj_data = struct('rxnTimes', {}, 'correct', {}, 'stimdB', {});

for ss = 1:length(subjectList)
    subjectID = subjectList{ss};
    subjectDataDir = fullfile(subjectDir, subjectID);

    rxnTimes_subj = [];
    correct_subj = [];
    stimdB_subj = [];

    for lightIdx = 1:length(NDLabel)
        for freqIdx = 1:length(refFreqSetHz)
            dataDir = fullfile(subjectDataDir,[modDirections{1} '_ND' NDLabel{lightIdx} '_shifted'],experimentName);
            for contrastIdx = 1:nContrasts
                for sideIdx = 1:nSides
                    % Pre-compute formatted strings for robustness
                    contrastStr = strrep(num2str(targetPhotoContrast(contrastIdx)), '.', 'x');
                    freqStr = num2str(refFreqSetHz(freqIdx));
                    
                    % Use sprintf for more robust string concatenation
                    psychFileStem = sprintf('%s_%s_%s_cont-%s_refFreq-%sHz_%s', ...
                        subjectID, modDirections{1}, experimentName, ...
                        contrastStr, freqStr, stimParamLabels{sideIdx});
                    
                    filename = fullfile(dataDir,psychFileStem);
                    if exist([filename '.mat'], 'file')
                        load(filename,'psychObj');
                        questData = psychObj.questData;
                        
                        % --- FIX: More robust data concatenation ---
                        % Get the trial data and ensure it's a row vector before concatenating.
                        % This avoids the "Invalid expression" error.
                        rxnTimes_subj = [rxnTimes_subj, reshape([questData.trialData.responseTimeSecs], 1, [])];
                        correct_subj = [correct_subj, reshape([questData.trialData.correct], 1, [])];
                        stimdB_subj = [stimdB_subj, reshape([questData.trialData.stim], 1, [])];
                    end
                end
            end
        end
    end
    subj_data(ss).rxnTimes = rxnTimes_subj;
    subj_data(ss).correct = correct_subj;
    subj_data(ss).stimdB = stimdB_subj;

    all_rxnTimes = [all_rxnTimes, rxnTimes_subj];
    all_stimdB = [all_stimdB, stimdB_subj];
end

% Determine global axis limits and add a small buffer for plotting
min_rxnTime = min(all_rxnTimes);
max_rxnTime = max(all_rxnTimes);
min_stimdB = min(all_stimdB);
max_stimdB = max(all_stimdB);
x_buffer = (max_stimdB - min_stimdB) * 0.05;
y_buffer = (max_rxnTime - min_rxnTime) * 0.05;

% Determine min and max of reciprocal reaction times
min_recipRxnTime = min(1./all_rxnTimes);
max_recipRxnTime = max(1./all_rxnTimes);

% Create a consistent set of bin edges for all histograms
nBins = 50;
binEdges = linspace(min_rxnTime - y_buffer, max_rxnTime + y_buffer, nBins + 1);

% --- Pass 2: Plot in a tiled format ---
figure('Position', [100, 100, 1000, 600]); % Adjust figure size for better viewing
t = tiledlayout(length(subjectList), 2, 'TileSpacing', 'compact', 'Padding', 'tight');
title(t, 'DCPT SDT Reaction Time Data', 'FontWeight', 'bold');

for ss = 1:length(subjectList)
    subjectID = subjectList{ss};
    rxnTimes = subj_data(ss).rxnTimes;
    correct = subj_data(ss).correct;
    stimdB = subj_data(ss).stimdB;
    
    % Skip subject if no data
    if isempty(rxnTimes)
        continue;
    end
    
    % Create Histogram Plot (Column 1)
    nexttile;
    % Use the consistent bin edges for the histogram
    histogram(rxnTimes, 'BinEdges', binEdges, 'FaceColor', [0 0.5 0.5]);
    ylabel('Count');
    xlabel('Reaction Time (sec)');
    title(subjectID);
    xlim([min_rxnTime - y_buffer, max_rxnTime + y_buffer]);
    
    % Create Scatter Plot (Column 2)
    nexttile;
    hold on;

    % Change variable to plot reciprocal of reaction times or regular
    rxnTimeRecip = true;
    if rxnTimeRecip
        rxnTimeVariable = 1./rxnTimes;
    else
        rxnTimeVariable = rxnTimes;
    end

    if plotCorrectOnly

        correctIdx = find(correct);

        % Plot only the correct trials with a transparent blue fill.
        scatter(stimdB(correctIdx), rxnTimeVariable(correctIdx), 40, 'o', ...
            'MarkerFaceColor', 'b', ...
            'MarkerFaceAlpha', 0.1, ...
            'MarkerEdgeColor', 'b', ...
            'MarkerEdgeAlpha', 0.2);

        % Find trials with correct responses and stimulus > 0dB
        fitIdx = correct & (stimdB > 0);

        % Fit a linear line to the filtered data
        p = polyfit(stimdB(fitIdx), rxnTimeVariable(fitIdx), 1);
        xFit = linspace(min(stimdB(fitIdx)), max(stimdB(fitIdx)), 100);
        yFit = polyval(p, xFit);

        % Plot the fitted line
        plot(xFit, yFit, 'k:', 'LineWidth', 2);

        % Calculate and add the correlation coefficient text
        if rxnTimeRecip
            if sum(fitIdx) > 1
                R = corrcoef(stimdB(fitIdx), rxnTimeVariable(fitIdx));
                text(min_stimdB + x_buffer, max_recipRxnTime - y_buffer, ...
                    sprintf('$R$ = %.2f', R(1,2)), ...
                    'FontSize', 12, 'FontWeight', 'bold', 'Interpreter', 'latex');
            end
        else
            if sum(fitIdx) > 1
                R = corrcoef(stimdB(fitIdx), rxnTimeVariable(fitIdx));
                text(min_stimdB + x_buffer, max_rxnTime - y_buffer, ...
                    sprintf('$R$ = %.2f', R(1,2)), ...
                    'FontSize', 12, 'FontWeight', 'bold', 'Interpreter', 'latex');
            end

        end

        legend('correct', 'Linear Fit', 'Location', 'best');

    else   % Will only plot regular rxnTimes, not reciprocal
        % Find correct and incorrect responses
        correctIdx = find(correct);
        wrongIdx = find(~correct);

            % Plot the correct trials with a transparent blue fill.
            scatter(stimdB(correctIdx), rxnTimes(correctIdx), 40, 'o', ...
                'MarkerFaceColor', 'b', ...
                'MarkerFaceAlpha', 0.1, ...
                'MarkerEdgeColor', 'b', ...
                'MarkerEdgeAlpha', 0.2);

            % Plot the incorrect trials with a transparent red fill.
            scatter(stimdB(wrongIdx), rxnTimes(wrongIdx), 40, 'o', ...
                'MarkerFaceColor', 'r', ...
                'MarkerFaceAlpha', 0.1, ...
                'MarkerEdgeColor', 'r', ...
                'MarkerEdgeAlpha', 0.2);

            % Fit a linear line to all the data
            p = polyfit(stimdB, rxnTimes, 1);
            xFit = linspace(min(stimdB), max(stimdB), 100);
            yFit = polyval(p, xFit);

            % Plot the fitted line
            plot(xFit, yFit, 'k:', 'LineWidth', 2);

            % Calculate and add the correlation coefficient text
            if length(stimdB) > 1 && length(rxnTimes) > 1
                R = corrcoef(stimdB, rxnTimes);
                text(min_stimdB + x_buffer, max_rxnTime - y_buffer, ...
                    sprintf('$R$ = %.2f', R(1,2)), ...
                    'FontSize', 12, 'FontWeight', 'bold', 'Interpreter', 'latex');
            end
            legend('correct', 'incorrect', 'Linear Fit', 'Location', 'best');
    end

        % Apply global axis limits with a buffer for scatter plots
        xlim([min_stimdB - x_buffer, max_stimdB + x_buffer]);
        if rxnTimeRecip
           ylim([min_recipRxnTime - y_buffer, max_recipRxnTime + y_buffer]);
           % ylim([min_recipRxnTime - y_buffer, 10]);
            title(sprintf('Stim Domain vs. Reaction Time for Subject: %s', subjectID));
            ylabel('1 / Reaction Time (sec)');
            xlabel('Stim Params (dB)');
            hold off;
        else
            ylim([min_rxnTime - y_buffer, max_rxnTime + y_buffer]);
            title(sprintf('Stim Domain vs. Reaction Time for Subject: %s', subjectID));
            ylabel('Reaction Time (sec)');
            xlabel('Stim Params (dB)');
            hold off;
        end

    end
end
