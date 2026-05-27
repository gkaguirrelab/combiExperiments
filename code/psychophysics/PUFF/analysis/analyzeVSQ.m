function [resultsAll, resultsEndorsed, data] = analyzeVSQ(filePath)
% ANALYZEVSQ Analyzes visual snow symptom questionnaire data and plots results.
%   [resultsAll, resultsEndorsed, data] = analyzeVSQ(filePath)
%   Outputs two sets of tables formatted with Mean ± SEM (n=X) to match the plots.

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
    has_Photophobia = (data.vssq_9_freq_v2 >= 2) | (data.vssq_12_freq_v2 >= 2); % Threshold >= 2 (Weekly)
    has_Nyctalopia  = (data.vssq_14_freq_v2 >= 3) | (data.vssq_15_freq_v2 >= 3);
    
    symptomPresence = [has_VS, has_Afterimages, has_Trails, has_Entoptic, has_Photophobia, has_Nyctalopia];
    symptomNames    = {'Visual Snow'; 'Afterimages'; 'Trails'; 'Entoptic Phenomena'; 'Photophobia'; 'Nyctalopia'};

    %% 3. Map Evaluation Metric Matrices
    % NOTE ON QUESTIONNAIRE SKIP LOGIC:
    % The raw dataset contains NaN entries for duration and bothersomeness variables
    % because the survey design implements conditional branch logic. If a participant
    % responds that they "Never" experience a given symptom, the questionnaire completely
    % skips asking them subsequent questions regarding duration or bothersomeness for it.
    
    % Duration Ratings Matrix (0 to 6)
    durationData = [data.vssq_1_duration_v2, data.vssq_3_dur_v2, data.vssq_4_dur_v2, ...
                    data.vssq_5_dur_v2,      data.vssq_9_dur_v2, NaN(height(data), 1)];
                
    % BOTHERSOME RATINGS (Figure 2 uses the MEAN for multi-question symptoms)
    botherData_Fig2 = [data.vssq_1_bother_v2, data.vssq_3_bother_v2, data.vssq_4_bother_v2, data.vssq_5_bother_v2, ...
                       mean([data.vssq_9_bother_v2, data.vssq_12_bother_v2], 2, 'omitnan'), ...
                       mean([data.vssq_14_bother_v2, data.vssq_15_bother_v2], 2, 'omitnan')];

    % INDIVIDUAL QUESTIONS (Figure 3 separates all 8 items explicitly)
    indivBotherData = [data.vssq_1_bother_v2,  data.vssq_3_bother_v2,  data.vssq_4_bother_v2,  data.vssq_5_bother_v2, ...
                       data.vssq_9_bother_v2,  data.vssq_12_bother_v2, data.vssq_14_bother_v2, data.vssq_15_bother_v2];
                   
    indivNames      = {'VS (Q1)', 'Afterimages (Q3)', 'Trails (Q4)', 'Entoptic (Q5)', ...
                       'Photophobia: Gives Headache (Q9)', 'Photophobia: Hurts Eyes (Q12)', ...
                       'Nyctalopia: Navigating Dark (Q14)', 'Nyctalopia: Depth Perception (Q15)'};
                   
    indivPresence   = [has_VS, has_Afterimages, has_Trails, has_Entoptic, ...
                       has_Photophobia, has_Photophobia, has_Nyctalopia, has_Nyctalopia];

    %% 4. Apply Group Exclusions & Aggregate Data
    vssSubjIdx     = (data.group == 1);
    excludedVSSIdx = vssSubjIdx & ~has_VS;
    nVSS_Excluded  = sum(excludedVSSIdx);
    
    validAnalysisIdx = ~(excludedVSSIdx);
    data             = data(validAnalysisIdx, :);
    symptomPresence  = symptomPresence(validAnalysisIdx, :);
    durationData     = durationData(validAnalysisIdx, :);
    botherData_Fig2  = botherData_Fig2(validAnalysisIdx, :);
    indivBotherData  = indivBotherData(validAnalysisIdx, :);
    indivPresence    = indivPresence(validAnalysisIdx, :);

    groupIds = [0, 1];
    groupLabels = {'Controls', 'VSS'};
    
    resultsAll = struct();
    resultsEndorsed = struct();
    
    nControls = sum(data.group == 0);
    nVSS      = sum(data.group == 1);
    
    for g = 1:length(groupIds)
        groupIdx = (data.group == groupIds(g));
        groupSize = sum(groupIdx);
        
        % Pre-allocate cell arrays for Table 1 (All)
        all_counts       = zeros(6, 1);
        all_percentages  = zeros(6, 1);
        all_avg_dur      = cell(6, 1);
        all_avg_bother   = cell(6, 1);
        
        % Pre-allocate cell arrays for Table 2 (Endorsed Only)
        endorsed_counts       = zeros(6, 1);
        endorsed_percentages  = zeros(6, 1);
        endorsed_avg_dur      = cell(6, 1);
        endorsed_avg_bother   = cell(6, 1);
        
        for s = 1:6
            % --- TABLE 1: ALL PARTICIPANTS IN GROUP (Using SEM) ---
            subDurAll   = durationData(groupIdx, s);
            subBothAll  = botherData_Fig2(groupIdx, s);
            
            all_counts(s)      = sum(symptomPresence(groupIdx, s), 'omitnan');
            all_percentages(s) = (all_counts(s) / groupSize) * 100;
            
            % Format Duration for All: Lock n to total group size
            nDurAllValid = sum(~isnan(subDurAll));
            if nDurAllValid > 0
                semDurAll = std(subDurAll, 'omitnan') / sqrt(nDurAllValid);
                all_avg_dur{s} = sprintf('%.2f ± %.2f (n=%d)', mean(subDurAll, 'omitnan'), semDurAll, groupSize);
            else
                all_avg_dur{s} = sprintf('NaN (n=%d)', groupSize);
            end
            
            % Format Bothersome for All: Lock n to total group size
            nBothAllValid = sum(~isnan(subBothAll));
            if nBothAllValid > 0
                semBothAll = std(subBothAll, 'omitnan') / sqrt(nBothAllValid);
                all_avg_bother{s} = sprintf('%.2f ± %.2f (n=%d)', mean(subBothAll, 'omitnan'), semBothAll, groupSize);
            else
                all_avg_bother{s} = sprintf('NaN (n=%d)', groupSize);
            end
            
            % --- TABLE 2: ENDORSED PARTICIPANTS ONLY (Using SEM) ---
            isEndorsedSubj = groupIdx & symptomPresence(:, s);
            nEndorsed = sum(isEndorsedSubj);
            
            subDurEndorsed  = durationData(isEndorsedSubj, s);
            subBothEndorsed = botherData_Fig2(isEndorsedSubj, s);
            
            endorsed_counts(s)      = nEndorsed;
            endorsed_percentages(s) = (nEndorsed / groupSize) * 100;
            
            % Format Duration for Endorsed: Reflect subset sample size
            nDurEndValid = sum(~isnan(subDurEndorsed));
            if nDurEndValid > 0
                semDurEnd = std(subDurEndorsed, 'omitnan') / sqrt(nDurEndValid);
                endorsed_avg_dur{s} = sprintf('%.2f ± %.2f (n=%d)', mean(subDurEndorsed, 'omitnan'), semDurEnd, nDurEndValid);
            else
                endorsed_avg_dur{s} = 'NaN (n=0)';
            end
            
            % Format Bothersome for Endorsed: Reflect subset sample size
            nBothEndValid = sum(~isnan(subBothEndorsed)); % <--- FIXED TYPO HERE
            if nBothEndValid > 0
                semBothEnd = std(subBothEndorsed, 'omitnan') / sqrt(nBothEndValid);
                endorsed_avg_bother{s} = sprintf('%.2f ± %.2f (n=%d)', mean(subBothEndorsed, 'omitnan'), semBothEnd, nBothEndValid);
            else
                endorsed_avg_bother{s} = 'NaN (n=0)';
            end
        end
        
        % Package Table 1: All Participants
        resultsAll.(groupLabels{g}) = table(symptomNames, all_counts, all_percentages, ...
            all_avg_dur, all_avg_bother, ...
            'VariableNames', {'Symptom', 'Count_Endorsed', 'Pct_Endorsed', ...
                              'Avg_Duration_Mean_SEM_n', 'Avg_Bothersome_Mean_SEM_n'});
            
        % Package Table 2: Endorsed Only
        resultsEndorsed.(groupLabels{g}) = table(symptomNames, endorsed_counts, endorsed_percentages, ...
            endorsed_avg_dur, endorsed_avg_bother, ...
            'VariableNames', {'Symptom', 'Count_Endorsed', 'Pct_Endorsed', ...
                              'Avg_Duration_Mean_SEM_n', 'Avg_Bothersome_Mean_SEM_n'});
    end

    %% 5. Print Tables to Command Window
    fprintf('========================================================================================\n');
    fprintf('                          VISUAL SNOW QUESTIONNAIRE ANALYSIS                            \n');
    fprintf('========================================================================================\n\n');
    
    fprintf('##### TABLE 1: ALL PARTICIPANTS (REGARDLESS OF SYMPTOM ENDORSEMENT) #####\n');
    fprintf('--- CONTROLS (Total N = %d) ---\n', nControls); disp(resultsAll.Controls);
    fprintf('\n--- VSS COHORT (Total Analyzed N = %d) ---\n', nVSS); disp(resultsAll.VSS);
    
    fprintf('\n##### TABLE 2: SYMPTOM-ENDORSED PARTICIPANTS ONLY (MATCHES PLOTS) #####\n');
    fprintf('--- CONTROLS (Total N = %d) ---\n', nControls); disp(resultsEndorsed.Controls);
    fprintf('\n--- VSS COHORT (Total Analyzed N = %d) ---\n', nVSS); disp(resultsEndorsed.VSS);
    
    fprintf('----------------------------------------------------------------------------------------\n');
    fprintf('EXCLUSIONS:\n');
    fprintf('  * Number of VSS participants excluded for lacking an ''All the time'' VS score: %d\n', nVSS_Excluded);
    fprintf('========================================================================================\n\n');

    %% 6. Plotting Results
    cControl = [0.40, 0.60, 0.90]; % Muted Blue
    cVSS     = [0.85, 0.35, 0.25]; % Coral/Red
    blueShades = [
        0.65, 0.80, 0.95;  % Tier 0
        0.40, 0.60, 0.85;  % Tier 1
        0.15, 0.35, 0.65;  % Tier 2
        0.05, 0.15, 0.40   % Tier 3
    ];

    % --- FIGURE 1: Bar Chart of Symptom Percentages ---
    figure('Name', 'Symptom Endorsement Percentages', 'Position', [100, 100, 750, 450]);
    barData = [resultsAll.Controls.Pct_Endorsed, resultsAll.VSS.Pct_Endorsed];
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

    % --- FIGURE 2: Multi-panel Histograms (Symptom-Averaged Scores) ---
    figure('Name', 'VSS Bothersomeness Distributions (Symptom Averages)', 'Position', [100, 100, 1250, 600]);
    subplotIndices = [1, 2, 3, 5, 6, 7];
    
    for s = 1:6
        subplot(2, 4, subplotIndices(s));
        hold on;
        
        isVSSSymptom = (data.group == 1) & symptomPresence(:, s) & ~isnan(botherData_Fig2(:, s));
        vssScores = botherData_Fig2(isVSSSymptom, s);
        nSymptomCount = length(vssScores);
        
        if nSymptomCount > 0
            pctCounts = zeros(4, 1);
            pctCounts(1) = (sum(vssScores >= 0   & vssScores <= 0.5) / nSymptomCount) * 100;
            pctCounts(2) = (sum(vssScores > 0.5  & vssScores <= 1.5) / nSymptomCount) * 100;
            pctCounts(3) = (sum(vssScores > 1.5  & vssScores <= 2.5) / nSymptomCount) * 100;
            pctCounts(4) = (sum(vssScores > 2.5  & vssScores <= 3.0) / nSymptomCount) * 100;
            
            for rating = 0:3
                bar(rating, pctCounts(rating + 1), 0.8, 'FaceColor', blueShades(rating + 1, :), 'EdgeColor', 'w');
            end
            
            avgBother = mean(vssScores);
            semBother = std(vssScores) / sqrt(nSymptomCount);
            
            yPlotAnchor = 88;
            errorbar(avgBother, yPlotAnchor, semBother, 'horizontal', ...
                     'Color', [0.2, 0.2, 0.2], 'LineWidth', 2, 'Marker', 'd', ...
                     'MarkerSize', 7, 'MarkerFaceColor', [0.2, 0.2, 0.2], 'CapSize', 6);
            
            ylabel(sprintf('Percent of participants (n = %d)', nSymptomCount), 'FontSize', 9);
        else
            text(1.5, 50, 'No Participants Endorsed', 'HorizontalAlignment', 'center', 'FontAngle', 'italic');
            ylabel('Percent of participants (n = 0)', 'FontSize', 9);
        end
        
        title(symptomNames{s}, 'FontSize', 12, 'FontWeight', 'bold');
        xlabel('Mean Severity Score', 'FontSize', 10);
        set(gca, 'XTick', 0:3, 'XLim', [-0.6, 3.6], 'YLim', [0, 100], 'YTick', 0:20:100, 'FontSize', 9);
        grid on; set(gca, 'XGrid', 'off'); box off;
    end
    
    guideTile2 = subplot(2, 4, [4, 8]); axis(guideTile2, 'off'); 
    textStr2 = {
        '\bf{Severity Score Guide (Averaged Bins):}', ...
        '  \color[rgb]{0.65, 0.80, 0.95}■ \color{black}\bf{0}: [0.0 - 0.5] Not bothersome', ...
        '  \color[rgb]{0.40, 0.60, 0.85}■ \color{black}\bf{1}: (0.5 - 1.5] Annoying/Manageable', ...
        '  \color[rgb]{0.15, 0.35, 0.65}■ \color{black}\bf{2}: (1.5 - 2.5] Bothersome', ...
        '  \color[rgb]{0.05, 0.15, 0.40}■ \color{black}\bf{3}: (2.5 - 3.0] Severely disruptive', ...
        '', ...
        '\bf{Plot Summary Indicators:}', ...
        '  \color[rgb]{0.20, 0.20, 0.20}◆\color{black} Mean', ...
        '  \color[rgb]{0.20, 0.20, 0.20}—\color{black} \pm1 SEM'
    };
    text(0.05, 0.50, textStr2, 'FontSize', 11, 'Interpreter', 'tex', 'Parent', guideTile2, ...
         'VerticalAlignment', 'middle', 'HorizontalAlignment', 'left');

    % --- FIGURE 3: Multi-panel Histograms (Each Question Separated) ---
    figure('Name', 'VSS Bothersomeness Distributions (Individual Questions)', 'Position', [100, 100, 1500, 650]);
    
    for q = 1:8
        subplot(2, 4, q);
        hold on;
        
        isVSSQuestion = (data.group == 1) & indivPresence(:, q) & ~isnan(indivBotherData(:, q));
        qScores = indivBotherData(isVSSQuestion, q);
        nQCount = length(qScores);
        
        if nQCount > 0
            pctCountsIndiv = zeros(4, 1);
            for rating = 0:3
                pctCountsIndiv(rating + 1) = (sum(qScores == rating) / nQCount) * 100;
            end
            
            for rating = 0:3
                bar(rating, pctCountsIndiv(rating + 1), 0.8, 'FaceColor', blueShades(rating + 1, :), 'EdgeColor', 'w');
            end
            
            avgBotherQ = mean(qScores);
            semBotherQ = std(qScores) / sqrt(nQCount);
            
            yPlotAnchorQ = 88;
            errorbar(avgBotherQ, yPlotAnchorQ, semBotherQ, 'horizontal', ...
                     'Color', [0.2, 0.2, 0.2], 'LineWidth', 2, 'Marker', 'd', ...
                     'MarkerSize', 7, 'MarkerFaceColor', [0.2, 0.2, 0.2], 'CapSize', 6);
            
            ylabel(sprintf('Percent of participants (n = %d)', nQCount), 'FontSize', 9);
        else
            text(1.5, 50, 'No Participants Endorsed', 'HorizontalAlignment', 'center', 'FontAngle', 'italic');
            ylabel('Percent of participants (n = 0)', 'FontSize', 9);
        end
        
        title(indivNames{q}, 'FontSize', 10, 'FontWeight', 'bold');
        xlabel('Severity Score', 'FontSize', 10);
        set(gca, 'XTick', 0:3, 'XLim', [-0.6, 3.6], 'YLim', [0, 100], 'YTick', 0:20:100, 'FontSize', 9);
        grid on; set(gca, 'XGrid', 'off'); box off;
    end
end