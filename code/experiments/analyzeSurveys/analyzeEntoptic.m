function analyzeEntoptic
%% Load data
% set up paths
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir = 'FLIC_data';
projectName = 'combiLED';
experimentName = 'DCPT_entoptic'; 
dataDir = fullfile(dropBoxBaseDir, dropBoxSubDir, projectName);

subjectIDM = {'FLIC_1016','FLIC_1029','FLIC_1030','FLIC_1031','FLIC_1032', ...
    'FLIC_1034','FLIC_1035','FLIC_1036','FLIC_1038', 'FLIC_1041', 'FLIC_1043',...
    'FLIC_1044', 'FLIC_1046', 'FLIC_1047', 'FLIC_1048'};
subjectIDC = {'FLIC_0013', 'FLIC_0015', 'FLIC_0017', ...
    'FLIC_0018', 'FLIC_0019','FLIC_0020', 'FLIC_0021', 'FLIC_0022', 'FLIC_0027',...
    'FLIC_0028','FLIC_0039', 'FLIC_0042', 'FLIC_0049', 'FLIC_0050', 'FLIC_0051'};

modDirection = 'LightFlux';
targetND = '0x5'; % Only have data for high light level

groups = {'Migraine', 'Control'};
groupIDs = {subjectIDM, subjectIDC};
results = struct();

% Loop through groups
for groupIdx = 1:length(groups)
    currentGroup = groups{groupIdx};
    currentSubjects = groupIDs{groupIdx};
    fprintf('Processing Group: %s...\n', currentGroup);
    
    for subjIdx = 1:length(currentSubjects)
        subject = currentSubjects{subjIdx};
        
        % Construct path for the High Light level only
        subFolderName = sprintf('%s_ND%s_shifted', modDirection, targetND);
        filePath = fullfile(dataDir, subject, subFolderName, experimentName, 'entoptic.mat');
        
        if exist(filePath, 'file')
            dataLoad = load(filePath, 'psychObj');
            subjField = matlab.lang.makeValidName(subject);
            
            % Extract entopticResponse instead of discomfortRating
            results.(currentGroup).(subjField).ratings   = dataLoad.psychObj.entopticResponse;
            results.(currentGroup).(subjField).contrast  = dataLoad.psychObj.contrastOrder;
            results.(currentGroup).(subjField).frequency = dataLoad.psychObj.refFreqOrder;
        else
            fprintf('   [!] Missing: %s\n', subject);
        end
    end
end
disp('Data loading complete.');

%% Plotting Logic
% Extract unique parameters from first valid subject
firstSub = fieldnames(results.(groups{1}));
sampleData = results.(groups{1}).(firstSub{1});
uniqueFreqs = unique(sampleData.frequency);
uniqueContrasts = unique(sampleData.contrast);

figure('Color', 'w', 'Position', [100, 100, 800, 600]); hold on;
hEntries = []; lEntries = {};

for groupIdx = 1:length(groups)
    grp = groups{groupIdx};
    subjects = fieldnames(results.(grp));
    
    % Group color assignment
    if strcmpi(grp, 'Migraine'), baseCol = [1, 0, 0]; else, baseCol = [0, 0.4, 1]; end
    
    % Apply "Hi Light" (ND 0x5) color shift: Maintain Hue, lower Saturation
    hsv = rgb2hsv(baseCol);
    lineCol = hsv2rgb([hsv(1), 0.4, 1]); % This matches the colors in the discomfort ratings files
    
    for contrastIdx = 1:length(uniqueContrasts)
        thisContrast = uniqueContrasts(contrastIdx);
        
        % Style: Lo Contrast (dashed/white), Hi Contrast (solid/filled)
        if thisContrast == min(uniqueContrasts)
            lineStyle = '--'; markerFace = 'w'; contName = 'Lo Contrast';
        else
            lineStyle = '-'; markerFace = lineCol; contName = 'Hi Contrast';
        end
        
        groupMeans = zeros(1, length(uniqueFreqs));
        groupSEM   = zeros(1, length(uniqueFreqs));
        
        for freqIdx = 1:length(uniqueFreqs)
            thisFreq = uniqueFreqs(freqIdx);
            subjAvgs = [];
            for subjIdx = 1:length(subjects)
                data = results.(grp).(subjects{subjIdx});
                idx = (abs(data.frequency - thisFreq) < 0.01) & (abs(data.contrast - thisContrast) < 0.01);
                if any(idx), subjAvgs(end+1) = mean(data.ratings(idx)); end
            end
            groupMeans(freqIdx) = mean(subjAvgs);
            groupSEM(freqIdx)   = std(subjAvgs) / sqrt(length(subjAvgs));
        end
        
        p = errorbar(uniqueFreqs, groupMeans, groupSEM, ...
            'Color', lineCol, 'LineStyle', lineStyle, 'LineWidth', 2, ...
            'Marker', 'o', 'MarkerSize', 8, 'MarkerFaceColor', markerFace, ...
            'CapSize', 0);
        
        hEntries(end+1) = p;
        lEntries{end+1} = sprintf('%s: %s', grp, contName);
    end
end

legend(hEntries, lEntries, 'Location', 'eastoutside');
set(gca, 'XScale', 'log', 'XTick', uniqueFreqs);
xlabel('Frequency (Hz)'); ylabel('Entoptic Phenomena Score');
title('Entoptic Scores (High Light Level Only)');
grid on; axis tight;
xlim([min(uniqueFreqs)*0.8, max(uniqueFreqs)*1.2]);

%% Stats
nMigraine = length(fieldnames(results.Migraine));
nControl  = length(fieldnames(results.Control));
nTotalSub = nMigraine + nControl;
nC = length(uniqueContrasts);
nF = length(uniqueFreqs);

% 3D Matrix: [Subjects x Contrast x Freq]
entopticMatrix = nan(nTotalSub, nC, nF);
subCounter = 0;

for groupIdx = 1:length(groups)
    grp = groups{groupIdx};
    subList = fieldnames(results.(grp));
    for subjIdx = 1:length(subList)
        subCounter = subCounter + 1;
        data = results.(grp).(subList{subjIdx});
        for contrastIdx = 1:nC
            for freqIdx = 1:nF
                idx = (abs(data.frequency - uniqueFreqs(freqIdx)) < 0.01) & ...
                      (abs(data.contrast - uniqueContrasts(contrastIdx)) < 0.01);
                if any(idx)
                    entopticMatrix(subCounter, contrastIdx, freqIdx) = mean(data.ratings(idx));
                end
            end
        end
    end
end

% Indices for 3 factors: Subject, Contrast, Frequency
[S_idx, C_idx, F_idx] = ndgrid(1:nTotalSub, 1:nC, 1:nF);
G_idx = ones(nTotalSub, nC, nF);
G_idx((nMigraine+1):end, :, :) = 2;

% Nesting: Subject (1) in Group (2)
nest = zeros(4, 4); nest(1, 2) = 1;
factors = {S_idx(:), G_idx(:), C_idx(:), F_idx(:)};
varnames = {'Subject', 'Group', 'Contrast', 'Frequency'};

fprintf('Running ANOVA for Entoptic Scores...\n');
[p, tbl, stats] = anovan(entopticMatrix(:), factors, ...
    'nested', nest, 'random', 1, 'model', 'interaction', 'varnames', varnames);

end