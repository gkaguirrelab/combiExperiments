function [results, data] = analyzeVSQ(filePath)
% ANALYZEVSQ Analyzes visual snow symptom questionnaire data and plots results.
%   [results, data] = analyzeVSQ() runs the analysis using the default path.
%   [results, data] = analyzeVSQ(filePath) runs on a custom provided file path.

    %% 1. Handle Default Arguments and Import Data
    if nargin < 1 || isempty(filePath)
        filePath = '/Users/samanthamontoya/Aguirre-Brainard Lab Dropbox/Sam Montoya/BLNK_analysis/VSQ/vpvss_VSQ2_data_20260220.csv';
    end
    
    if ~exist(filePath, 'file')
        error('The file could not be found at path:\n%s\nPlease check your folder path.', filePath);
    end
    % Import dataset, explicitly skipping the 1st row of descriptive text headers
    opts = detectImportOptions(filePath);
    opts.DataLines = [2, Inf]; 
    data = readtable(filePath, opts);

    %% 2. Define Symptom Presence Thresholds (Logical Tracking)
    % 0=Never, 1=Monthly, 2=Weekly, 3=Daily, 4=Several/day, 5=All the time
    has_VS          = data.vssq_1_freq_v2 == 5;
    has_Afterimages = data.vssq_3_freq_v2 >= 3;
    has_Trails      = data.vssq_4_freq_v2 >= 3;
    has_Entoptic    = data.vssq_5_freq_v2 >= 3;
    has_Photophobia = (data.vssq_9_freq_v2 >= 3) | (data.vssq_12_freq_v2 >= 3);
    has_Nyctalopia  = (data.vssq_14_freq_v2 >= 3) | (data.vssq_15_freq_v2 >= 3);
    symptomPresence = [has_VS, has_Afterimages, has_Trails, has_Entoptic, has_Photophobia, has_Nyctalopia];
    symptomNames    = {'Visual Snow'; 'Afterimages'; 'Trails'; 'Entoptic Phenomena'; 'Photophobia'; 'Nyctalopia'};

    %% 3. Map Evaluation Metric Matrices
    % Duration Ratings Matrix (0 to 6)
    durationData = [data.vssq_1_duration_v2, data.vssq_3_dur_v2, data.vssq_4_dur_v2, ...
                    data.vssq_5_dur_v2,      data.vssq_9_dur_v2, NaN(height(data), 1)];
    % Bothersome Ratings Matrix (0 to 3)
    botherData = [data.vssq_1_bother_v2, data.vssq_3_bother_v2, data.vssq_4_bother_v2, data.vssq_5_bother_v2, ...
                  max([data.vssq_9_bother_v2, data.vssq_12_bother_v2], [], 2), ...
                  max([data.vssq_14_bother_v2, data.vssq_15_bother_v2], [], 2)];

    %% 4. Aggregate Mean & SD Statistics by Cohort Group
    groupIds = [0, 1];
    groupLabels = {'Controls', 'VSS'};
    results = struct();
    
    nControls = sum(data.group == 0);
    nVSS      = sum(data.group == 1);
    for g = 1:length(groupIds)
        groupIdx = (data.group == groupIds(g));
        groupSize = sum(groupIdx);
        
        counts          = zeros(6, 1);
        percentages     = zeros(6, 1);
        avg_duration    = zeros(6, 1); sd_dur    = zeros(6, 1);
        avg_bothersome  = zeros(6, 1); sd_bother = zeros(6, 1);
        
        for s = 1:6
            subDur   = durationData(groupIdx, s);
            subBoth  = botherData(groupIdx, s);
            
            counts(s) = sum(symptomPresence(groupIdx, s), 'omitnan');
            percentages(s) = (counts(s) / groupSize) * 100;
            
            avg_duration(s) = mean(subDur, 'omitnan');
            sd_dur(s)       = std(subDur, 'omitnan');
            
            avg_bothersome(s) = mean(subBoth, 'omitnan');
            sd_bother(s)      = std(subBoth, 'omitnan');
        end
        
        results.(groupLabels{g}) = table(symptomNames, counts, percentages, ...
            avg_duration, sd_dur, avg_bothersome, sd_bother, ...
            'VariableNames', {'Symptom', 'Count_Endorsed', 'Pct_Endorsed', ...
                              'Avg_Duration', 'SD_Duration', 'Avg_Bothersome', 'SD_Bothersome'});
    end

    %% 5. Print Summary to Command Window
    fprintf('========================================================================================\n');
    fprintf('                          VISUAL SNOW QUESTIONNAIRE ANALYSIS                            \n');
    fprintf('========================================================================================\n\n');
    fprintf('--- CONTROLS (Group 0, Total N = %d) ---\n', nControls); disp(results.Controls);
    fprintf('\n--- VSS COHORT (Group 1, Total N = %d) ---\n', nVSS); disp(results.VSS);
    
    % Print count of VSS group participants who don't meet the frequency threshold for VS
    nVSS_without_VS = sum(data.group == 1 & ~has_VS);
    fprintf('----------------------------------------------------------------------------------------\n');
    fprintf('Note: Number of participants in the VSS group who do NOT meet VS criteria: %d\n', nVSS_without_VS);
    fprintf('========================================================================================\n\n');

    %% 6. Plotting Results
    cControl = [0.40, 0.60, 0.90]; % Muted Blue
    cVSS     = [0.85, 0.35, 0.25]; % Coral/Red
    % Blue Severity Tiers: 0 (Light) to 3 (Dark)
    blueShades = [
        0.65, 0.80, 0.95;  % 0: Light Sky Blue
        0.40, 0.60, 0.85;  % 1: Medium Blue
        0.15, 0.35, 0.65;  % 2: Dark Blue
        0.05, 0.15, 0.40   % 3: Deep Navy Blue
    ];

    % --- FIGURE 1: Bar Chart of Symptom Percentages ---
    figure('Name', 'Symptom Endorsement Percentages', 'Position', [100, 100, 750, 450]);
    barData = [results.Controls.Pct_Endorsed, results.VSS.Pct_Endorsed];
    hBar = bar(barData, 'grouped');
    hBar(1).FaceColor = cControl;
    hBar(2).FaceColor = cVSS;
    
    set(gca, 'XTickLabel', symptomNames, 'TickLabelInterpreter', 'none', 'FontSize', 11);
    xtickangle(25);
    ylabel('Percent of Participants', 'FontSize', 12, 'FontWeight', 'bold');
    title('Symptom Endorsement Rates Across Groups', 'FontSize', 14, 'FontWeight', 'bold');
    
    legendStr = {sprintf('Controls (n = %d)', nControls), sprintf('VSS (n = %d)', nVSS)};
    legend(legendStr, 'Location', 'NorthEast', 'FontSize', 10);
    
    set(gca, 'YGrid', 'on', 'XGrid', 'off', 'YMinorGrid', 'off', 'YTick', 0:10:100);
    box off;

    % --- FIGURE 2: Multi-panel Percent Histograms with Dedicated Guide Tile ---
    figure('Name', 'VSS Bothersomeness Distributions', 'Position', [100, 100, 1250, 600]);
    
    % Array maps our 6 symptoms to their specific tiles in a 2x4 layout
    subplotIndices = [1, 2, 3, 5, 6, 7];
    
    for s = 1:6
        subplot(2, 4, subplotIndices(s));
        hold on;
        
        isVSSSymptom = (data.group == 1) & symptomPresence(:, s) & ~isnan(botherData(:, s));
        vssScores = botherData(isVSSSymptom, s);
        nSymptomCount = length(vssScores);
        
        if nSymptomCount > 0
            % Compute percentage metrics for individual integer steps
            pctCounts = zeros(4, 1);
            for rating = 0:3
                pctCounts(rating + 1) = (sum(vssScores == rating) / nSymptomCount) * 100;
            end
            
            % Generate customized gradient bars
            for rating = 0:3
                bar(rating, pctCounts(rating + 1), 0.8, 'FaceColor', blueShades(rating + 1, :), 'EdgeColor', 'w');
            end
            
            % Statistical Calculations
            avgBother = mean(vssScores);
            semBother = std(vssScores) / sqrt(nSymptomCount);
            
            % Anchor summary errorbar at a fixed position near the top ceiling (88%)
            yPlotAnchor = 88;
            
            errorbar(avgBother, yPlotAnchor, semBother, 'horizontal', ...
                     'Color', [0.2, 0.2, 0.2], 'LineWidth', 2, 'Marker', 'd', ...
                     'MarkerSize', 7, 'MarkerFaceColor', [0.2, 0.2, 0.2], 'CapSize', 6);
            
            ylabel(sprintf('Percent of participants (n = %d)', nSymptomCount), 'FontSize', 9);
        else
            text(1.5, 50, 'No Participants Endorsed', 'HorizontalAlignment', 'center', 'FontAngle', 'italic');
            ylabel('Percent of participants (n = 0)', 'FontSize', 9);
        end
        
        % Standardized Axis Properties
        title(symptomNames{s}, 'FontSize', 12, 'FontWeight', 'bold');
        xlabel('Severity Score', 'FontSize', 10);
        
        % Force all Y-Axes uniformly to 100%
        set(gca, 'XTick', 0:3, 'XLim', [-0.6, 3.6], 'YLim', [0, 100], 'YTick', 0:20:100, 'FontSize', 9);
        grid on; set(gca, 'XGrid', 'off');
        box off;
    end
    
    % --- DEDICATED SIDE TILE FOR THE GUIDE PANEL ---
    % Merge tiles 4 and 8 (the entire rightmost column) to form a unified side panel
    guideTile = subplot(2, 4, [4, 8]);
    axis(guideTile, 'off'); 
    
    textStr = {
        '\bf{Severity Score Guide:}', ...
        '  \color[rgb]{0.65, 0.80, 0.95}■ \color{black}\bf{0}: Is not bothersome', ...
        '  \color[rgb]{0.40, 0.60, 0.85}■ \color{black}\bf{1}: Annoying but manageable', ...
        '  \color[rgb]{0.15, 0.35, 0.65}■ \color{black}\bf{2}: Is bothersome', ...
        '  \color[rgb]{0.05, 0.15, 0.40}■ \color{black}\bf{3}: Severely affects daily tasks', ...
        '', ...
        '\bf{Plot Summary Indicators:}', ...
        '  \color[rgb]{0.20, 0.20, 0.20}◆\color{black} Center diamond represents Mean', ...
        '  \color[rgb]{0.20, 0.20, 0.20}—\color{black} Whiskers span \pm1 SEM'
    };
    
    % Position text inside its isolated grid column
    text(0.05, 0.50, textStr, 'FontSize', 11, 'Interpreter', 'tex', 'Parent', guideTile, ...
         'VerticalAlignment', 'middle', 'HorizontalAlignment', 'left');
end