%% PLOT LOG-FREQUENCY HISTOGRAMS (CB-FRIENDLY GRADIENT)
% Distinguishes trials belonging to each reference frequency using a gradient.

% --- SETUP PARAMETERS ---
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir = 'FLIC_data';
projectName = 'combiLED';
experimentName = 'DCPT_SDT';
subjectID = {'FLIC_1016','FLIC_1029','FLIC_1030','FLIC_1031','FLIC_1032', ...
    'FLIC_1034','FLIC_1035','FLIC_1036','FLIC_1038', 'FLIC_1041', 'FLIC_1043',...
    'FLIC_1044', 'FLIC_1046', 'FLIC_1047'};
modDirection = 'LightFlux';
NDLabel = {'3x0', '0x5'};   
stimParamLabels = {'low', 'hi'}; 
refFreqHz = logspace(log10(10),log10(30),5);  
targetPhotoContrast = {'0x1','0x3'};  

nFreqs = length(refFreqHz);
nContrasts = length(targetPhotoContrast);
nLightLevels = length(NDLabel);
nSubj = length(subjectID);

% --- COLOR SETUP (Color-Blind Friendly Gradient) ---
% Using 'viridis' if available, otherwise 'parula'
try
    cmap = viridis(nFreqs);
catch
    cmap = parula(nFreqs);
end

% --- DATA LOADING ---
freqData = struct();
allHzObserved = []; 

for c = 1:nContrasts
    for l = 1:nLightLevels
        % Initialize cell arrays to hold data per reference frequency
        freqData(c, l).refGroup = cell(1, nFreqs);
        freqData(c, l).physicallySameHz = [];
    end
end

for subjIdx = 1:nSubj
    thisSubj = subjectID{subjIdx};
    for lightIdx = 1:nLightLevels
        for refFreqIdx = 1:nFreqs
            currentRef = refFreqHz(refFreqIdx);
            for contrastIdx = 1:nContrasts
                for sideIdx = 1:length(stimParamLabels)
                    fileName = fullfile(dropBoxBaseDir, dropBoxSubDir, projectName, thisSubj, ...
                        [modDirection '_ND' NDLabel{lightIdx} '_shifted'], experimentName, ...
                        [thisSubj '_' modDirection '_' experimentName ...
                        '_cont-' targetPhotoContrast{contrastIdx} '_refFreq-' num2str(currentRef) 'Hz_' ...
                        stimParamLabels{sideIdx} '.mat']);
                    
                    if exist(fileName, 'file')
                        load(fileName,'psychObj')
                        trialData = psychObj.questData.trialData;
                        stims_dB = [trialData.stim];
                        
                        % Physical Identity Logic
                        isPhysSame = (abs(stims_dB) < 1e-5);
                        isPhysDiff = ~isPhysSame;
                        
                        % Frequency Conversion
                        if strcmp(stimParamLabels{sideIdx}, 'low'), stims_dB = -stims_dB; end
                        tests_Hz = currentRef * 10.^(stims_dB / 20);
                        
                        % Store based on reference index for color coding
                        freqData(contrastIdx, lightIdx).refGroup{refFreqIdx} = ...
                            [freqData(contrastIdx, lightIdx).refGroup{refFreqIdx}, tests_Hz(isPhysDiff)];
                        
                        freqData(contrastIdx, lightIdx).physicallySameHz = ...
                            [freqData(contrastIdx, lightIdx).physicallySameHz, tests_Hz(isPhysSame)];
                        
                        allHzObserved = [allHzObserved, tests_Hz];
                    end
                end
            end
        end
    end
end

% --- PLOTTING ---
figure('Color', 'w', 'Position', [100, 100, 1200, 800]);
t = tiledlayout(nContrasts, nLightLevels, 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, 'Trial Distributions Categorized by Reference Frequency', 'FontSize', 16);

% Set Dynamic Range
plotMin = 10^(log10(min(allHzObserved)) - 0.05);
plotMax = 10^(log10(max(allHzObserved)) + 0.05);
logEdges = logspace(log10(plotMin), log10(plotMax), 80);

for c = 1:nContrasts
    for l = 1:nLightLevels
        nexttile; hold on;
        dat = freqData(c,l);
        
        % 1. Plot Physically SAME (Reference peaks) in dark grey
        histogram(dat.physicallySameHz, logEdges, 'FaceColor', [0.1 0.1 0.1], ...
            'EdgeColor', 'none', 'FaceAlpha', 0.9, 'DisplayName', '0dB Ref');
            
        % 2. Plot Physically DIFFERENT trials (Color coded by Ref)
        for rf = 1:nFreqs
            if ~isempty(dat.refGroup{rf})
                histogram(dat.refGroup{rf}, logEdges, ...
                    'FaceColor', cmap(rf,:), ...
                    'EdgeColor', cmap(rf,:), ...
                    'FaceAlpha', 0.4, ...
                    'LineWidth', 1, ...
                    'DisplayName', sprintf('Ref %0.1f Hz', refFreqHz(rf)));
            end
        end
            
        set(gca, 'XScale', 'log');
        xlim([plotMin plotMax]); 
        set(gca, 'XTick', [5 10 15 20 30 45 60 80 100]);
        xtickformat('%g');
        grid on;
        
        title(sprintf('Contrast: %s | ND: %s', targetPhotoContrast{c}, NDLabel{l}));
        if c == 1 && l == 1, legend('Location', 'northeast', 'FontSize', 7, 'NumColumns', 2); end
    end
end

xlabel(t, 'Frequency (Hz)', 'FontSize', 14);
ylabel(t, 'Trial Count', 'FontSize', 14);
linkaxes(findobj(t, 'Type', 'axes'), 'xy');