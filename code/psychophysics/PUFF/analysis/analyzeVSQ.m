function [resultsAll, resultsEndorsed, data, closedEyesFreqTable] = analyzeVSQ(filePath, saveFigures, vssOnlyFig1)
% ANALYZEVSQ Analyzes visual snow symptom questionnaire data and plots results.
%   [resultsAll, resultsEndorsed, data, closedEyesFreqTable] = analyzeVSQ(filePath, saveFigures, vssOnlyFig1)
%
%   Inputs:
%       filePath     - Path to the CSV data file (Optional)
%       saveFigures  - Boolean (true/false) to save figures to individual PDFs (Default: true)
%       vssOnlyFig1  - Boolean (true/false) to only plot VSS cohort in Figure 1 (Default: false)
%
%   Outputs tables formatted with Mean ± SEM (n=X) to match the plots, 
%   plus a frequency breakdown for closed-eye colorful clouds/waves.

    %% 1. Handle Default Arguments and Import Data
    if nargin < 1 || isempty(filePath)
        filePath = '/Users/samanthamontoya/Aguirre-Brainard Lab Dropbox/Sam Montoya/BLNK_analysis/VSQ/vpvss_VSQ2_data_20260611.csv';
    end
    
    if nargin < 2 || isempty(saveFigures)
        saveFigures = true; 
    end

    if nargin < 3 || isempty(vssOnlyFig1)
        vssOnlyFig1 = true;
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
    has_Photophobia = (data.vssq_9_freq_v2 >= 2) | (data.vssq_12_freq_v2 >= 2); 
    has_Nyctalopia  = (data.vssq_14_freq_v2 >= 3) | (data.vssq_15_freq_v2 >= 3);
    
    symptomPresence = [has_VS, has_Afterimages, has_Trails, has_Entoptic, has_Photophobia, has_Nyctalopia];
    symptomNames    = {'Visual Snow'; 'Afterimages'; 'Trails'; 'Entoptic Phenomena'; 'Photophobia'; 'Nyctalopia'};

    %% 3. Map Evaluation Metric Matrices
    durationData = [data.vssq_1_duration_v2, data.vssq_3_dur_v2, data.vssq_4_dur_v2, ...
                    data.vssq_5_dur_v2,      data.vssq_9_dur_v2, NaN(height(data), 1)];
                
    botherData_Fig2 = [data.vssq_1_bother_v2, data.vssq_3_bother_v2, data.vssq_4_bother_v2, data.vssq_5_bother_v2, ...
                       mean([data.vssq_9_bother_v2, data.vssq_12_bother_v2], 2, 'omitnan'), ...
                       mean([data.vssq_14_bother_v2, data.vssq_15_bother_v2], 2, 'omitnan')];
                   
    indivBotherData = [data.vssq_1_bother_v2,  data.vssq_3_bother_v2,  data.vssq_4_bother_v2,  data.vssq_5_bother_v2, ...
                       data.vssq_9_bother_v2,  data.vssq_12_bother_v2, data.vssq_14_bother_v2, data.vssq_15_bother_v2];
                   
    indivNames      = {'VS (Q1)', 'Afterimages (Q3)', 'Trails (Q4)', 'Entoptic (Q5)', ...
                       'Photophobia: Gives Headache (Q9)', 'Photophobia: Hurts Eyes (Q12)', ...
                       'Nyctalopia: Navigating Dark (Q14)', 'Nyctalopia: Depth Perception (Q15)'};
                   
    indivPresence   = [has_VS, has_Afterimages, has_Trails, has_Entoptic, ...
                       has_Photophobia, has_Photophobia, has_Nyctalopia, has_Nyctalopia];

    %% 4. Handle Group Parsing Dynamically
    if isnumeric(data.group) || islogical(data.group)
        vssSubjIdx = (data.group == 1);
    else
        vssSubjIdx = strcmpi(string(data.group), '1') | strcmpi(string(data.group), 'VSS');
    end
    excludedVSSIdx = vssSubjIdx & ~has_VS;
    nVSS_Excluded  = sum(excludedVSSIdx);
    
    validAnalysisIdx = ~(excludedVSSIdx);
    data             = data(validAnalysisIdx, :);
    symptomPresence  = symptomPresence(validAnalysisIdx, :);
    durationData     = durationData(validAnalysisIdx, :);
    botherData_Fig2  = botherData_Fig2(validAnalysisIdx, :);
    indivBotherData  = indivBotherData(validAnalysisIdx, :);
    indivPresence    = indivPresence(validAnalysisIdx, :);
    
    if isnumeric(data.group) || islogical(data.group)
        vssGroupLogical = (data.group == 1);
        controlGroupLogical = (data.group == 0);
    else
        vssGroupLogical = strcmpi(string(data.group), '1') | strcmpi(string(data.group), 'VSS');
        controlGroupLogical = strcmpi(string(data.group), '0') | strcmpi(string(data.group), 'Control') | strcmpi(string(data.group), 'Controls');
    end
    nControls = sum(controlGroupLogical);
    nVSS      = sum(vssGroupLogical);
    
    groupLogicals = {controlGroupLogical, vssGroupLogical};
    groupLabels = {'Controls', 'VSS'};
    
    resultsAll = struct();
    resultsEndorsed = struct();
    
    for g = 1:2
        groupIdx = groupLogicals{g};
        groupSize = sum(groupIdx);
        
        all_counts       = zeros(6, 1);
        all_percentages  = zeros(6, 1);
        all_avg_dur      = cell(6, 1);
        all_avg_bother   = cell(6, 1);
        
        endorsed_counts       = zeros(6, 1);
        endorsed_percentages  = zeros(6, 1);
        endorsed_avg_dur      = cell(6, 1);
        endorsed_avg_bother   = cell(6, 1);
        
        for s = 1:6
            subDurAll   = durationData(groupIdx, s);
            subBothAll  = botherData_Fig2(groupIdx, s);
            
            all_counts(s)      = sum(symptomPresence(groupIdx, s), 'omitnan');
            all_percentages(s) = (all_counts(s) / max(1, groupSize)) * 100;
            
            nDurAllValid = sum(~isnan(subDurAll));
            if nDurAllValid > 0
                semDurAll = std(subDurAll, 'omitnan') / sqrt(nDurAllValid);
                all_avg_dur{s} = sprintf('%.2f ± %.2f (n=%d)', mean(subDurAll, 'omitnan'), semDurAll, groupSize);
            else
                all_avg_dur{s} = sprintf('NaN (n=%d)', groupSize);
            end
            
            nBothAllValid = sum(~isnan(subBothAll));
            if nBothAllValid > 0
                semBothAll = std(subBothAll, 'omitnan') / sqrt(nBothAllValid);
                all_avg_bother{s} = sprintf('%.2f ± %.2f (n=%d)', mean(subBothAll, 'omitnan'), semBothAll, groupSize);
            else
                all_avg_bother{s} = sprintf('NaN (n=%d)', groupSize);
            end
            
            isEndorsedSubj = groupIdx & symptomPresence(:, s);
            nEndorsed = sum(isEndorsedSubj);
            
            subDurEndorsed  = durationData(isEndorsedSubj, s);
            subBothEndorsed = botherData_Fig2(isEndorsedSubj, s);
            
            endorsed_counts(s)      = nEndorsed;
            endorsed_percentages(s) = (nEndorsed / max(1, groupSize)) * 100;
            
            nDurEndValid = sum(~isnan(subDurEndorsed));
            if nDurEndValid > 0
                semDurEnd = std(subDurEndorsed, 'omitnan') / sqrt(nDurEndValid);
                endorsed_avg_dur{s} = sprintf('%.2f ± %.2f (n=%d)', mean(subDurEndorsed, 'omitnan'), semDurEnd, nDurEndValid);
            else
                endorsed_avg_dur{s} = 'NaN (n=0)';
            end
            
            nBothEndValid = sum(~isnan(subBothEndorsed));
            if nBothEndValid > 0
                semBothEnd = std(subBothEndorsed, 'omitnan') / sqrt(nBothEndValid);
                endorsed_avg_bother{s} = sprintf('%.2f ± %.2f (n=%d)', mean(subBothEndorsed, 'omitnan'), semBothEnd, nBothEndValid);
            else
                endorsed_avg_bother{s} = 'NaN (n=0)';
            end
        end
        
        resultsAll.(groupLabels{g}) = table(symptomNames, all_counts, all_percentages, ...
            all_avg_dur, all_avg_bother, ...
            'VariableNames', {'Symptom', 'Count_Endorsed', 'Pct_Endorsed', ...
                              'Avg_Duration_Mean_SEM_n', 'Avg_Impact_Mean_SEM_n'});
            
        resultsEndorsed.(groupLabels{g}) = table(symptomNames, endorsed_counts, endorsed_percentages, ...
            endorsed_avg_dur, endorsed_avg_bother, ...
            'VariableNames', {'Symptom', 'Count_Endorsed', 'Pct_Endorsed', ...
                              'Avg_Duration_Mean_SEM_n', 'Avg_Impact_Mean_SEM_n'});
    end

    %% 4b. Calculate Frequencies for Closed-Eye Colorful Clouds/Waves
    freqLabels = {'0: Never'; '1: Monthly'; '2: Weekly'; '3: Daily'; '4: Several times a day'; '5: All the time'};
    
    ctrlClouds = data.vssq_7_freq_v2(controlGroupLogical);
    vssClouds  = data.vssq_7_freq_v2(vssGroupLogical);
    
    ctrlCloudsValid = ctrlClouds(~isnan(ctrlClouds));
    vssCloudsValid  = vssClouds(~isnan(vssClouds));
    
    nCtrlValid = length(ctrlCloudsValid);
    nVSSValid  = length(vssCloudsValid);
    
    ctrlCounts = zeros(6, 1); ctrlPct = zeros(6, 1);
    vssCounts  = zeros(6, 1); vssPct  = zeros(6, 1);
    
    for f = 0:5
        ctrlCounts(f+1) = sum(ctrlCloudsValid == f);
        vssCounts(f+1)  = sum(vssCloudsValid == f);
    end
    
    if nCtrlValid > 0, ctrlPct = (ctrlCounts / nCtrlValid) * 100; end
    if nVSSValid > 0,  vssPct  = (vssCounts / nVSSValid) * 100; end
    
    closedEyesFreqTable = table(freqLabels, ctrlCounts, ctrlPct, vssCounts, vssPct, ...
        'VariableNames', {'Frequency_Rating', 'Controls_Count', 'Controls_Percent', 'VSS_Count', 'VSS_Percent'});

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
    
    fprintf('\n##### TABLE 3: FREQUENCY METRICS FOR "COLORFUL CLOUDS/WAVES (EYES CLOSED)" #####\n');
    fprintf('Normalized across participants with valid response metrics (n = %d Control, %d VSS):\n\n', nCtrlValid, nVSSValid);
    disp(closedEyesFreqTable);
    
    fprintf('----------------------------------------------------------------------------------------\n');
    fprintf('EXCLUSIONS:\n');
    fprintf('  * Number of VSS participants excluded for lacking an ''All the time'' VS score: %d\n', nVSS_Excluded);
    fprintf('========================================================================================\n\n');

    %% 6. Plotting Results
    cControl = [0.40, 0.60, 0.90]; 
    cVSS     = [0.85, 0.35, 0.25]; 
    blueShades = [0.65, 0.80, 0.95; 0.40, 0.60, 0.85; 0.15, 0.35, 0.65; 0.05, 0.15, 0.40];
    
    figHandles = gobjects(6, 1);

    % --- FIGURE 1: Bar Chart of Symptom Percentages ---
    figHandles(1) = figure('Name', 'Symptom Endorsement Percentages', 'Position', [100, 100, 750, 450], 'Color', 'w');
    
    if vssOnlyFig1
        % Extract VSS data and sort from most to least frequent
        vssPercentages = resultsAll.VSS.Pct_Endorsed;
        [sortedPct, sortIdx] = sort(vssPercentages, 'descend');
        sortedNames = symptomNames(sortIdx);
        
        % Plot single series
        hBar = bar(sortedPct);
        hBar.BarWidth = 0.6;
        hBar.FaceColor = 'flat'; % Enable per-bar coloring
        
        % Find where 'Visual Snow' ended up after sorting and lighten it
        for idx = 1:length(sortedNames)
            if strcmp(sortedNames{idx}, 'Visual Snow')
                % Blend original cVSS with white to make a lighter version (70% tint)
                hBar.CData(idx, :) = cVSS + (1 - cVSS) * 0.5; 
            else
                hBar.CData(idx, :) = cVSS; % Normal baseline VSS red
            end
        end
        
        % Set labels and title (No legend, "cohort" removed)
        set(gca, 'XTickLabel', sortedNames, 'TickLabelInterpreter', 'none', 'FontSize', 11, 'Color', 'w', ...
                 'XColor', [0 0 0], 'YColor', [0 0 0]);
        title(sprintf('Symptom Endorsement Rates (VSS, n = %d)', nVSS), 'FontSize', 14, 'FontWeight', 'bold', 'Color', [0 0 0]);
    else
        % Grouped layout matching original behavior (unsorted)
        barData = [resultsAll.Controls.Pct_Endorsed, resultsAll.VSS.Pct_Endorsed];
        hBar = bar(barData, 'grouped');
        hBar(1).FaceColor = cControl; hBar(2).FaceColor = cVSS;
        
        set(gca, 'XTickLabel', symptomNames, 'TickLabelInterpreter', 'none', 'FontSize', 11, 'Color', 'w', ...
                 'XColor', [0 0 0], 'YColor', [0 0 0]);
        hLegend1 = legend({sprintf('Controls (n = %d)', nControls), sprintf('VSS (n = %d)', nVSS)}, 'Location', 'NorthEast', 'TextColor', [0 0 0]);
        set(hLegend1, 'EdgeColor', 'none'); 
        title('Symptom Endorsement Rates Across Groups', 'FontSize', 14, 'FontWeight', 'bold', 'Color', [0 0 0]);
    end
    
    xtickangle(25); 
    ylabel('Percent of Participants', 'FontSize', 11, 'FontWeight', 'bold', 'Color', [0 0 0]); 
    set(gca, 'YGrid', 'on', 'XGrid', 'off', 'YTick', 0:10:100); box off;
    
    % --- FIGURE 2: Multi-panel Histograms (Symptom-Averaged Scores) ---
    figHandles(2) = figure('Name', 'VSS Symptom Impact Distributions (Symptom Averages)', 'Position', [100, 100, 1250, 600], 'Color', 'w');
    subplotIndices = [1, 2, 3, 5, 6, 7];
    for s = 1:6
        subplot(2, 4, subplotIndices(s)); hold on;
        isVSSSymptom = vssGroupLogical & symptomPresence(:, s) & ~isnan(botherData_Fig2(:, s));
        vssScores = botherData_Fig2(isVSSSymptom, s);
        nSymptomCount = length(vssScores);
        if nSymptomCount > 0
            pctCounts = [sum(vssScores<=0.5); sum(vssScores>0.5 & vssScores<=1.5); sum(vssScores>1.5 & vssScores<=2.5); sum(vssScores>2.5)] / nSymptomCount * 100;
            for rating = 0:3
                bar(rating, pctCounts(rating+1), 0.8, 'FaceColor', blueShades(rating+1,:), 'EdgeColor', 'w');
            end
            errorbar(mean(vssScores), 88, std(vssScores)/sqrt(nSymptomCount), 'horizontal', 'Color', [0 0 0], 'LineWidth', 2, 'Marker', 'd', 'MarkerSize', 7, 'MarkerFaceColor', [0 0 0]);
            ylabel(sprintf('Percent of Cohort (n = %d)', nSymptomCount), 'FontSize', 9, 'Color', [0 0 0]);
        else
            text(1.5, 50, 'No Participants Endorsed', 'HorizontalAlignment', 'center', 'FontAngle', 'italic', 'Color', [0 0 0]);
            ylabel('Percent of Cohort (n = 0)', 'FontSize', 9, 'Color', [0 0 0]);
        end
        title(symptomNames{s}, 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0 0]);
        xlabel('Impact Rating', 'FontSize', 10, 'Color', [0 0 0]);
        set(gca, 'XTick', 0:3, 'XLim', [-0.6, 3.6], 'YLim', [0, 100], 'YTick', 0:20:100, 'Color', 'w', ...
                 'XColor', [0 0 0], 'YColor', [0 0 0]); 
        grid on; set(gca, 'XGrid', 'off', 'YGrid', 'on'); box off;
    end
    guideTile2 = subplot(2, 4, [4, 8]); axis(guideTile2, 'off'); 
    textStr2 = {'\bf{Impact Rating Guide (Averaged Bins):}', '  \color[rgb]{0.65, 0.80, 0.95}■ \color{black}\bf{0}: [0.0 - 0.5] Not bothersome', '  \color[rgb]{0.40, 0.60, 0.85}■ \color{black}\bf{1}: (0.5 - 1.5] Annoying/Manageable', '  \color[rgb]{0.15, 0.35, 0.65}■ \color{black}\bf{2}: (1.5 - 2.5] Bothersome', '  \color[rgb]{0.05, 0.15, 0.40}■ \color{black}\bf{3}: (2.5 - 3.0] Severely disruptive', '', '\bf{Plot Summary Indicators:}', '  \color{black}◆ Mean', '  \color{black}— \pm1 SEM'};
    text(0.05, 0.50, textStr2, 'FontSize', 11, 'Interpreter', 'tex', 'Parent', guideTile2, 'VerticalAlignment', 'middle', 'Color', [0 0 0]);

    % --- FIGURE 3: Multi-panel Histograms (Each Question Separated) ---
    figHandles(3) = figure('Name', 'VSS Symptom Impact Distributions (Individual Questions)', 'Position', [100, 100, 1500, 650], 'Color', 'w');
    for q = 1:8
        subplot(2, 4, q); hold on;
        isVSSQuestion = vssGroupLogical & indivPresence(:, q) & ~isnan(indivBotherData(:, q));
        qScores = indivBotherData(isVSSQuestion, q);
        nQCount = length(qScores);
        if nQCount > 0
            for rating = 0:3
                bar(rating, (sum(qScores==rating)/nQCount)*100, 0.8, 'FaceColor', blueShades(rating+1,:), 'EdgeColor', 'w');
            end
            errorbar(mean(qScores), 88, std(qScores)/sqrt(nQCount), 'horizontal', 'Color', [0 0 0], 'LineWidth', 2, 'Marker', 'd', 'MarkerSize', 7, 'MarkerFaceColor', [0 0 0]);
            ylabel(sprintf('Percent of Cohort (n = %d)', nQCount), 'FontSize', 9, 'Color', [0 0 0]);
        else
            text(1.5, 50, 'No Participants Endorsed', 'HorizontalAlignment', 'center', 'FontAngle', 'italic', 'Color', [0 0 0]);
            ylabel('Percent of Cohort (n = 0)', 'FontSize', 9, 'Color', [0 0 0]);
        end
        title(indivNames{q}, 'FontSize', 10, 'FontWeight', 'bold', 'Color', [0 0 0]); 
        xlabel('Impact Rating', 'FontSize', 10, 'Color', [0 0 0]);
        set(gca, 'XTick', 0:3, 'XLim', [-0.6, 3.6], 'YLim', [0, 100], 'YTick', 0:20:100, 'Color', 'w', ...
                 'XColor', [0 0 0], 'YColor', [0 0 0]); 
        grid on; set(gca, 'XGrid', 'off', 'YGrid', 'on'); box off;
    end

    % Base variables common to Figures 4 and 5
    likertColors = [
        0.82, 0.82, 0.84;  
        0.50, 0.70, 0.90;  
        0.90, 0.80, 0.60;  
        0.90, 0.55, 0.35;  
        0.80, 0.25, 0.25   
    ];
    textOffset = 0.40;

    % --- FIGURE 4: True Diverging Stacked Layout (VSS Profiles) ---
    figHandles(4) = figure('Name', 'VSS Symptom Severity Profiles: Diverging Around Zero', 'Position', [100, 100, 1250, 600], 'Color', 'w');
    hold on;
    
    pctMatrixVSS = zeros(6, 5);
    for s = 1:6
        if s == 1,     freq = data.vssq_1_freq_v2;
        elseif s == 2, freq = data.vssq_3_freq_v2;
        elseif s == 3, freq = data.vssq_4_freq_v2;
        elseif s == 4, freq = data.vssq_5_freq_v2;
        elseif s == 5, freq = max([data.vssq_9_freq_v2, data.vssq_12_freq_v2], [], 2); 
        elseif s == 6, freq = max([data.vssq_14_freq_v2, data.vssq_15_freq_v2], [], 2);
        end
        bother = botherData_Fig2(:, s);
        
        isAbsent = vssGroupLogical & (freq == 0 | isnan(freq));
        isActive = vssGroupLogical & (freq > 0 & ~isnan(bother));
        rowDenominator = max(1, sum(isAbsent) + sum(isActive)); 
        vssScores = bother(isActive);
        
        pctMatrixVSS(s, 1) = (sum(isAbsent) / rowDenominator) * 100;
        if ~isempty(vssScores)
            pctMatrixVSS(s, 2) = (sum(vssScores <= 0.5) / rowDenominator) * 100;                 
            pctMatrixVSS(s, 3) = (sum(vssScores > 0.5 & vssScores <= 1.5) / rowDenominator) * 100;  
            pctMatrixVSS(s, 4) = (sum(vssScores > 1.5 & vssScores <= 2.5) / rowDenominator) * 100;  
            pctMatrixVSS(s, 5) = (sum(vssScores > 2.5) / rowDenominator) * 100;                 
        end
    end
    
    hLeftVSS = barh(1:6, -[pctMatrixVSS(:, 2), pctMatrixVSS(:, 1)], 0.55, 'stacked', 'EdgeColor', 'none');
    hLeftVSS(1).FaceColor = likertColors(2,:); hLeftVSS(2).FaceColor = likertColors(1,:);
    hRightVSS = barh(1:6, [pctMatrixVSS(:, 3), pctMatrixVSS(:, 4), pctMatrixVSS(:, 5)], 0.55, 'stacked', 'EdgeColor', 'none');
    hRightVSS(1).FaceColor = likertColors(3,:); hRightVSS(2).FaceColor = likertColors(4,:); hRightVSS(3).FaceColor = likertColors(5,:);

    for s = 1:6
        pAbsent = pctMatrixVSS(s, 1); pNeutral = pctMatrixVSS(s, 2); pAnnoying = pctMatrixVSS(s, 3); pBother = pctMatrixVSS(s, 4); pSevere = pctMatrixVSS(s, 5);
        if pAbsent > 0
            text(-pNeutral - (pAbsent / 2), s + textOffset, sprintf('%.0f%%', pAbsent), 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontSize', 9.5, 'Color', [0 0 0], 'FontWeight', 'bold');
        end
        if pNeutral > 0
            text(-(pNeutral / 2), s + textOffset, sprintf('%.0f%%', pNeutral), 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontSize', 9.5, 'Color', [0 0 0], 'FontWeight', 'bold');
        end
        if pAnnoying > 0
            text(pAnnoying / 2, s + textOffset, sprintf('%.0f%%', pAnnoying), 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontSize', 9.5, 'Color', [0 0 0], 'FontWeight', 'bold');
        end
        if pBother > 0
            text(pAnnoying + (pBother / 2), s + textOffset, sprintf('%.0f%%', pBother), 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontSize', 9.5, 'Color', [0 0 0], 'FontWeight', 'bold');
        end
        if pSevere > 0
            text(pAnnoying + pBother + (pSevere / 2), s + textOffset, sprintf('%.0f%%', pSevere), 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontSize', 9.5, 'Color', [0 0 0], 'FontWeight', 'bold');
        end
    end
    line([0 0], [0.4, 6.6], 'Color', [0 0 0], 'LineWidth', 2.5);
    set(gca, 'YTick', 1:6, 'YTickLabel', symptomNames, 'YLim', [0.4, 6.6], 'XLim', [-105, 105], 'FontSize', 11, 'Color', 'w', ...
             'XColor', [0 0 0], 'YColor', [0 0 0]);
    xlabel('← No Current Impact (Symptom Absent / Rating 0, %)   |   Active Symptom Impact (Ratings 1-3, %) →', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0 0]);
    title(sprintf('VSS symptom impact profiles (n = %d)', nVSS), 'FontSize', 14, 'FontWeight', 'bold', 'Color', [0 0 0]);
    grid on; set(gca, 'YGrid', 'off', 'XGrid', 'on'); box off;
    
    hL1 = arrayfun(@(i) patch(NaN, NaN, likertColors(i,:), 'EdgeColor', 'none'), 1:5);
    hLegend4 = legend(hL1, {'Symptom Absent', '0: Not bothersome', '1: Annoying but manageable', '2: Bothersome', '3: Severely affects daily activities'}, 'Location', 'EastOutside', 'Orientation', 'vertical', 'FontSize', 10, 'TextColor', [0 0 0]);
    set(hLegend4, 'EdgeColor', 'none');


    % --- FIGURE 5: True Diverging Stacked Layout (Controls Profile Repeat) ---
    figHandles(5) = figure('Name', 'Control Symptom Severity Profiles: Diverging Around Zero', 'Position', [100, 100, 1250, 600], 'Color', 'w');
    hold on;
    
    pctMatrixCtrl = zeros(6, 5);
    for s = 1:6
        if s == 1,     freq = data.vssq_1_freq_v2;
        elseif s == 2, freq = data.vssq_3_freq_v2;
        elseif s == 3, freq = data.vssq_4_freq_v2;
        elseif s == 4, freq = data.vssq_5_freq_v2;
        elseif s == 5, freq = max([data.vssq_9_freq_v2, data.vssq_12_freq_v2], [], 2); 
        elseif s == 6, freq = max([data.vssq_14_freq_v2, data.vssq_15_freq_v2], [], 2);
        end
        bother = botherData_Fig2(:, s);
        
        isAbsent = controlGroupLogical & (freq == 0 | isnan(freq));
        isActive = controlGroupLogical & (freq > 0 & ~isnan(bother));
        rowDenominator = max(1, sum(isAbsent) + sum(isActive)); 
        ctrlScores = bother(isActive);
        
        pctMatrixCtrl(s, 1) = (sum(isAbsent) / rowDenominator) * 100;
        if ~isempty(ctrlScores)
            pctMatrixCtrl(s, 2) = (sum(ctrlScores <= 0.5) / rowDenominator) * 100;                 
            pctMatrixCtrl(s, 3) = (sum(ctrlScores > 0.5 & ctrlScores <= 1.5) / rowDenominator) * 100;  
            pctMatrixCtrl(s, 4) = (sum(ctrlScores > 1.5 & ctrlScores <= 2.5) / rowDenominator) * 100;  
            pctMatrixCtrl(s, 5) = (sum(ctrlScores > 2.5) / rowDenominator) * 100;                 
        end
    end
    
    hLeftCtrl = barh(1:6, -[pctMatrixCtrl(:, 2), pctMatrixCtrl(:, 1)], 0.55, 'stacked', 'EdgeColor', 'none');
    hLeftCtrl(1).FaceColor = likertColors(2,:); hLeftCtrl(2).FaceColor = likertColors(1,:);
    hRightCtrl = barh(1:6, [pctMatrixCtrl(:, 3), pctMatrixCtrl(:, 4), pctMatrixCtrl(:, 5)], 0.55, 'stacked', 'EdgeColor', 'none');
    hRightCtrl(1).FaceColor = likertColors(3,:); hRightCtrl(2).FaceColor = likertColors(4,:); hRightCtrl(3).FaceColor = likertColors(5,:);

    for s = 1:6
        pAbsent = pctMatrixCtrl(s, 1); pNeutral = pctMatrixCtrl(s, 2); pAnnoying = pctMatrixCtrl(s, 3); pBother = pctMatrixCtrl(s, 4); pSevere = pctMatrixCtrl(s, 5);
        if pAbsent > 0
            text(-pNeutral - (pAbsent / 2), s + textOffset, sprintf('%.0f%%', pAbsent), 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontSize', 9.5, 'Color', [0 0 0], 'FontWeight', 'bold');
        end
        if pNeutral > 0
            text(-(pNeutral / 2), s + textOffset, sprintf('%.0f%%', pNeutral), 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontSize', 9.5, 'Color', [0 0 0], 'FontWeight', 'bold');
        end
        if pAnnoying > 0
            text(pAnnoying / 2, s + textOffset, sprintf('%.0f%%', pAnnoying), 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontSize', 9.5, 'Color', [0 0 0], 'FontWeight', 'bold');
        end
        if pBother > 0
            text(pAnnoying + (pBother / 2), s + textOffset, sprintf('%.0f%%', pBother), 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontSize', 9.5, 'Color', [0 0 0], 'FontWeight', 'bold');
        end
        if pSevere > 0
            text(pAnnoying + pBother + (pSevere / 2), s + textOffset, sprintf('%.0f%%', pSevere), 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontSize', 9.5, 'Color', [0 0 0], 'FontWeight', 'bold');
        end
    end
    line([0 0], [0.4, 6.6], 'Color', [0 0 0], 'LineWidth', 2.5);
    set(gca, 'YTick', 1:6, 'YTickLabel', symptomNames, 'YLim', [0.4, 6.6], 'XLim', [-105, 105], 'FontSize', 11, 'Color', 'w', ...
             'XColor', [0 0 0], 'YColor', [0 0 0]);
    xlabel('← No Current Impact (Symptom Absent / Rating 0, %)   |   Active Symptom Impact (Ratings 1-3, %) →', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0 0]);
    title(sprintf('Controls symptom impact profiles (n = %d)', nControls), 'FontSize', 14, 'FontWeight', 'bold', 'Color', [0 0 0]);
    grid on; set(gca, 'YGrid', 'off', 'XGrid', 'on'); box off;
    
    hL2 = arrayfun(@(i) patch(NaN, NaN, likertColors(i,:), 'EdgeColor', 'none'), 1:5);
    hLegend5 = legend(hL2, {'Symptom Absent', '0: Not bothersome', '1: Annoying but manageable', '2: Bothersome', '3: Severely affects daily activities'}, 'Location', 'EastOutside', 'Orientation', 'vertical', 'FontSize', 10, 'TextColor', [0 0 0]);
    set(hLegend5, 'EdgeColor', 'none');


    % --- FIGURE 6: Average Symptom Impact Comparison ---
    figHandles(6) = figure('Name', 'Group Comparison: Average Symptom Impact Scores', 'Position', [100, 100, 970, 520], 'Color', 'w');
    hold on;
    
    alphaLevel = 0.15;
    patch([-0.5, 0.5, 0.5, -0.5], [0, 0, 7, 7], likertColors(2,:), 'EdgeColor', 'none', 'FaceAlpha', alphaLevel);
    patch([0.5, 1.5, 1.5, 0.5], [0, 0, 7, 7], likertColors(3,:), 'EdgeColor', 'none', 'FaceAlpha', alphaLevel);
    patch([1.5, 2.5, 2.5, 1.5], [0, 0, 7, 7], likertColors(4,:), 'EdgeColor', 'none', 'FaceAlpha', alphaLevel);
    patch([2.5, 3.0, 3.0, 2.5], [0, 0, 7, 7], likertColors(5,:), 'EdgeColor', 'none', 'FaceAlpha', alphaLevel);

    meanScores = zeros(6, 2); semScores  = zeros(6, 2); 
    for s = 1:6
        ctrlRawBother = botherData_Fig2(controlGroupLogical, s);
        vssRawBother  = botherData_Fig2(vssGroupLogical, s);
        ctrlRawBother(isnan(ctrlRawBother)) = 0;
        vssRawBother(isnan(vssRawBother))   = 0;
        
        meanScores(s, 1) = mean(ctrlRawBother);
        meanScores(s, 2) = mean(vssRawBother);
        semScores(s, 1)  = std(ctrlRawBother) / sqrt(length(ctrlRawBother));
        semScores(s, 2)  = std(vssRawBother) / sqrt(length(vssRawBother));
    end
    
    yBase = 1:6; yOffset = 0.12; 
    yControl = yBase - yOffset; 
    yVSS     = yBase + yOffset;
    
    errorbar(meanScores(:, 1), yControl, semScores(:, 1), 'horizontal', 'LineStyle', 'none', 'Color', cControl, 'LineWidth', 2, 'CapSize', 6);
    hCtrlDot = plot(meanScores(:, 1), yControl, 'o', 'MarkerSize', 8.5, 'MarkerFaceColor', cControl, 'MarkerEdgeColor', cControl * 0.6, 'LineWidth', 1);
        
    errorbar(meanScores(:, 2), yVSS, semScores(:, 2), 'horizontal', 'LineStyle', 'none', 'Color', cVSS, 'LineWidth', 2, 'CapSize', 6);
    hVSSDot = plot(meanScores(:, 2), yVSS, 'o', 'MarkerSize', 8.5, 'MarkerFaceColor', cVSS, 'MarkerEdgeColor', cVSS * 0.6, 'LineWidth', 1);
    
    set(gca, 'YTick', 1:6, 'YTickLabel', symptomNames, 'TickLabelInterpreter', 'none', 'FontSize', 11, 'Color', 'w', ...
             'XColor', [0 0 0], 'YColor', [0 0 0]);
    ylim([0.4, 6.6]); xlim([-0.5, 3]); set(gca, 'XTick', -0.5:0.5:3);
    
    xlabel('Average Symptom Impact Score (Absent treated as 0)', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0 0]);
    title('Average Symptom Impact Scores', 'FontSize', 14, 'FontWeight', 'bold', 'Color', [0 0 0]);
    
    hDummyGroupTitle = plot(NaN, NaN, 'w.', 'MarkerSize', 0.1); hDummySpacer = plot(NaN, NaN, 'w.', 'MarkerSize', 0.1); hDummyScoreTitle = plot(NaN, NaN, 'w.', 'MarkerSize', 0.1);
    hDummy0 = patch(NaN, NaN, likertColors(2,:), 'EdgeColor', 'none', 'FaceAlpha', alphaLevel * 2);
    hDummy1 = patch(NaN, NaN, likertColors(3,:), 'EdgeColor', 'none', 'FaceAlpha', alphaLevel * 2);
    hDummy2 = patch(NaN, NaN, likertColors(4,:), 'EdgeColor', 'none', 'FaceAlpha', alphaLevel * 2);
    hDummy3 = patch(NaN, NaN, likertColors(5,:), 'EdgeColor', 'none', 'FaceAlpha', alphaLevel * 2);
    
    legendList = [hDummyGroupTitle; hVSSDot; hCtrlDot; hDummySpacer; hDummyScoreTitle; hDummy0; hDummy1; hDummy2; hDummy3];
    legendLabels = {'\bf{Cohort Group}'; sprintf('VSS (n = %d)', nVSS); sprintf('Controls (n = %d)', nControls); ''; '\bf{Score Metric Key}'; '[0.0 to 0.5]: Not bothersome'; '(0.5 to 1.5]: Annoying / Manageable'; '(1.5 to 2.5]: Bothersome'; '(2.5 to 3.0]: Severely disruptive'};
    
    hLegend6 = legend(legendList, legendLabels, 'Location', 'EastOutside', 'FontSize', 10, 'Interpreter', 'tex', 'TextColor', [0 0 0]);
    set(hLegend6, 'EdgeColor', 'none'); 
    grid on; set(gca, 'YGrid', 'off', 'XGrid', 'on'); box off;

    %% 7. Individual Page PDF Export Step
    if saveFigures
        [dataDir, ~, ~] = fileparts(filePath);
        outputDir = fullfile(dataDir, 'figures');
        if ~exist(outputDir, 'dir')
            mkdir(outputDir);
        end
        
        fprintf('Saving figures as individual vector PDFs...\n');
        
        for f = 1:length(figHandles)
            targetFig = figHandles(f);
            
            if isgraphics(targetFig)
                % Generate a distinct file name for each figure index
                pdfPath = fullfile(outputDir, sprintf('VSQ_Figure_%d.pdf', f));
                
                % Append is false so it creates/overwrites its own clean single-page file
                exportgraphics(targetFig, pdfPath, 'ContentType', 'vector', 'Append', false);
                fprintf('  -> Exported Figure %d to: %s\n', f, pdfPath);
            end
        end
        fprintf('Successfully exported all individual figures.\n\n');
    end
end