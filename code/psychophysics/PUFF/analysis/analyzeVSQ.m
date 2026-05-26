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
    fprintf('--- CONTROLS (Group 0, Total N = %d) ---\n', sum(data.group == 0)); disp(results.Controls);
    fprintf('\n--- VSS COHORT (Group 1, Total N = %d) ---\n', sum(data.group == 1)); disp(results.VSS);

    %% 6. Plotting Results
    % Color Palette Definition
    cControl = [0.40, 0.60, 0.90]; % Muted Blue
    cVSS     = [0.85, 0.35, 0.25]; % Coral/Red

    % --- FIGURE 1: Histogram / Bar Chart of Symptom Counts ---
    figure('Name', 'Symptom Endorsement Counts', 'Position', [100, 100, 750, 450]);
    barData = [results.Controls.Count_Endorsed, results.VSS.Count_Endorsed];
    hBar = bar(barData, 'grouped');
    hBar(1).FaceColor = cControl;
    hBar(2).FaceColor = cVSS;
    
    set(gca, 'XTickLabel', symptomNames, 'TickLabelInterpreter', 'none', 'FontSize', 11);
    xtickangle(25);
    ylabel('Number of Participants', 'FontSize', 12, 'FontWeight', 'bold');
    title('Symptom Endorsement Counts Across Groups', 'FontSize', 14, 'FontWeight', 'bold');
    legend({'Controls (Group 0)', 'VSS (Group 1)'}, 'Location', 'NorthEast', 'FontSize', 10);
    grid on; grid minor;
    box off;

    % --- FIGURE 2: Bee Swarm Plot with Mean + SEM Error Bars ---
    figure('Name', 'Bothersome Scores Distribution', 'Position', [150, 150, 850, 500]);
    hold on;
    
    % Track categories explicitly for positioning on the X-axis
    for s = 1:6
        % Get scores for participants who actually experienced/endorsed the symptom
        % This filters out non-endorsers and NaNs organically
        isControlSymptom = (data.group == 0) & symptomPresence(:, s) & ~isnan(botherData(:, s));
        isVSSSymptom     = (data.group == 1) & symptomPresence(:, s) & ~isnan(botherData(:, s));
        
        controlScores = botherData(isControlSymptom, s);
        vssScores     = botherData(isVSSSymptom, s);
        
        % Plot Control Swarm (Offset slightly left to X-position 's')
        if ~isempty(controlScores)
            xControl = repmat(s - 0.18, length(controlScores), 1);
            swarmchart(xControl, controlScores, 25, cControl, 'filled', 'XJitter', 'density', 'MarkerFaceAlpha', 0.5);
            
            % Compute summary parameters
            mC   = mean(controlScores);
            semC = std(controlScores) / sqrt(length(controlScores));
            
            % Overlay Mean + Standard Error Bar
            errorbar(s - 0.18, mC, semC, 'Color', shadowColor(cControl), 'LineWidth', 2, 'Marker', 'o', ...
                     'MarkerSize', 8, 'MarkerFaceColor', cControl, 'CapSize', 8);
        end
        
        % Plot VSS Swarm (Offset slightly right to X-position 's')
        if ~isempty(vssScores)
            xVSS = repmat(s + 0.18, length(vssScores), 1);
            swarmchart(xVSS, vssScores, 25, cVSS, 'filled', 'XJitter', 'density', 'MarkerFaceAlpha', 0.5);
            
            % Compute summary parameters
            mV   = mean(vssScores);
            semV = std(vssScores) / sqrt(length(vssScores));
            
            % Overlay Mean + Standard Error Bar
            errorbar(s + 0.18, mV, semV, 'Color', shadowColor(cVSS), 'LineWidth', 2, 'Marker', 'o', ...
                     'MarkerSize', 8, 'MarkerFaceColor', cVSS, 'CapSize', 8);
        end
    end
    
    % Refine Swarm Plot Styling Layout
    set(gca, 'XLim', [0.5, 6.5], 'XTick', 1:6, 'XTickLabel', symptomNames, 'FontSize', 11);
    xtickangle(25);
    ylabel('Bothersomeness Severity Score', 'FontSize', 12, 'FontWeight', 'bold');
    title('Bothersomeness Ratings for Endorsed Symptoms Only', 'FontSize', 14, 'FontWeight', 'bold');
    
    % Dummy plots just to generate a clean, accurate legend
    p1 = plot(NaN, NaN, 'ob', 'MarkerFaceColor', cControl, 'MarkerSize', 7);
    p2 = plot(NaN, NaN, 'or', 'MarkerFaceColor', cVSS, 'MarkerSize', 7);
    legend([p1, p2], {'Controls (Group 0)', 'VSS (Group 1)'}, 'Location', 'SouthEast', 'FontSize', 10);
    
    grid on;
    box off;
    hold off;
end

function darkColor = shadowColor(rgb)
    % Helper sub-function to generate a darker line color for clear error bars
    darkColor = rgb * 0.65;
end