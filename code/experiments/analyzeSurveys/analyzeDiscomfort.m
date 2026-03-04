function analyzeDiscomfort
%% Load data
% set up paths
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir = 'FLIC_data';
projectName = 'combiLED';
experimentName = 'DCPT_discomfort';
dataDir = fullfile(dropBoxBaseDir, dropBoxSubDir, projectName);

subjectIDM =  {'FLIC_1016','FLIC_1029','FLIC_1030','FLIC_1031','FLIC_1032', ...
    'FLIC_1034','FLIC_1035','FLIC_1036','FLIC_1038', 'FLIC_1041', 'FLIC_1043',...
    'FLIC_1044', 'FLIC_1046', 'FLIC_1047', 'FLIC_1048'};
subjectIDC = {'FLIC_0013', 'FLIC_0015', 'FLIC_0017', ...
    'FLIC_0018', 'FLIC_0019','FLIC_0020', 'FLIC_0021', 'FLIC_0022', 'FLIC_0027',...
    'FLIC_0028','FLIC_0039', 'FLIC_0042', 'FLIC_0049', 'FLIC_0050', 'FLIC_0051'};

modDirection = 'LightFlux';
NDLabel = {'3x0', '0x5'};

% Define the groups and their corresponding subject lists
groups = {'Migraine', 'Control'};
groupIDs = {subjectIDM, subjectIDC};

% Initialize a structure to hold the output
results = struct();

%loop through groups
for groupIdx = 1:length(groups)
    currentGroup = groups{groupIdx};
    currentSubjects = groupIDs{groupIdx};

    fprintf('Processing Group: %s...\n', currentGroup);

    %loop through participants
    for subjIdx = 1:length(currentSubjects)
        subject = currentSubjects{subjIdx};

        %loop through light levels
        for lightIdx = 1:length(NDLabel)
            subFolderName = sprintf('%s_ND%s_shifted', modDirection, NDLabel{lightIdx});
            filePath = fullfile(dataDir, subject, subFolderName, experimentName, 'discomfort.mat');

            if exist(filePath, 'file')
                dataLoad = load(filePath, 'psychObj');

                % Store in results.(Group).(Subject).(NDLabel)
                % makeValidName ensures the 'FLIC_XXXX' and '3x0' labels work as field names
                subjField = matlab.lang.makeValidName(subject);
                ndField = matlab.lang.makeValidName(['ND_', NDLabel{lightIdx}]);

                results.(currentGroup).(subjField).(ndField).ratings   = dataLoad.psychObj.discomfortRating;
                results.(currentGroup).(subjField).(ndField).contrast  = dataLoad.psychObj.contrastOrder;
                results.(currentGroup).(subjField).(ndField).frequency = dataLoad.psychObj.refFreqOrder;

            else
                fprintf('   [!] Missing: %s | %s\n', subject, NDLabel{lightIdx});
            end
        end
    end
end

disp('Data loading complete.');

%% Plot mean discomfort ratings by condition
% Dynamic Parameter Extraction
firstSub = fieldnames(results.(groups{1}));
firstND  = fieldnames(results.(groups{1}).(firstSub{1}));
sampleData = results.(groups{1}).(firstSub{1}).(firstND{1});

uniqueFreqs = unique(sampleData.frequency);
uniqueContrasts = unique(sampleData.contrast);

% Plotting Section
% Define Base Colors
redBase  = [1, 0, 0]; %for migraine
blueBase = [0, 0.4, 1]; %for controls

figure('Color', 'w', 'Position', [100, 100, 1000, 700]); hold on;

% Initialize table for stats
statsTable = table();

% Initialize storage for legend handles and labels
hEntries = [];
lEntries = {};

%loop through groups
for groupIdx = 1:length(groups)
    grp = groups{groupIdx};
    subjects = fieldnames(results.(grp));

    % Color assignment
    if strcmpi(grp, 'Migraine'), baseCol = [1, 0, 0]; else, baseCol = [0, 0.4, 1]; end

    for lightIdx = 1:length(NDLabel)
        ndField = matlab.lang.makeValidName(['ND_', NDLabel{lightIdx}]);
        hsv = rgb2hsv(baseCol);

        if strcmp(NDLabel{lightIdx}, '3x0')
            lineCol = hsv2rgb([hsv(1), hsv(2), 0.6]);
            lightName = 'Lo Light';
        else
            lineCol = hsv2rgb([hsv(1), 0.4, 1]);
            lightName = 'Hi Light';
        end

        %loop through contrast
        for contrastIdx = 1:length(uniqueContrasts)
            thisContrast = uniqueContrasts(contrastIdx);

            % Styling
            if thisContrast == min(uniqueContrasts)
                lineStyle = '--'; markerFace = 'w';
                contName = 'Lo Contrast';
            else
                lineStyle = '-'; markerFace = lineCol;
                contName = 'Hi Contrast';
            end

            % --- Calculate Mean and SEM ---
            groupMeans = zeros(1, length(uniqueFreqs));
            groupSEM   = zeros(1, length(uniqueFreqs));
            %frequency loop
            for freqIdx = 1:length(uniqueFreqs)
                thisFreq = uniqueFreqs(freqIdx);
                subjAvgs = [];
                %subject loop
                for subjIdx = 1:length(subjects)
                    data = results.(grp).(subjects{subjIdx}).(ndField);
                    idx = (abs(data.frequency - thisFreq) < 0.01) & (abs(data.contrast - thisContrast) < 0.01);
                    if any(idx), subjAvgs(end+1) = mean(data.ratings(idx)); end
                end
                groupMeans(freqIdx) = mean(subjAvgs);
                groupSEM(freqIdx)   = std(subjAvgs) / sqrt(length(subjAvgs));
            end

            % Plot and capture the handle for the legend
            p = errorbar(uniqueFreqs, groupMeans, groupSEM, ...
                'Color', lineCol, 'LineStyle', lineStyle, 'LineWidth', 2, ...
                'Marker', 'o', 'MarkerSize', 8, 'MarkerFaceColor', markerFace, ...
                'CapSize', 0);

            % Store handle and create specific label
            hEntries(end+1) = p;
            lEntries{end+1} = sprintf('%s: %s, %s', grp, lightName, contName);
        end
    end
end

% Create the detailed legend
legend(hEntries, lEntries, 'Location', 'eastoutside', 'FontSize', 9);

% Final Formatting
set(gca, 'XScale', 'log', 'XTick', uniqueFreqs, 'FontSize', 11);
xlabel('Frequency (Hz)'); ylabel('Discomfort Rating');
title('Discomfort Ratings by Condition');
grid on; axis tight;
xlim([min(uniqueFreqs)*0.8, max(uniqueFreqs)*1.2]);

%% Stats
% Get dimensions
nMigraine = length(fieldnames(results.Migraine));
nControl  = length(fieldnames(results.Control));
nTotalSub = nMigraine + nControl;
nC = length(uniqueContrasts);
nL = length(NDLabel);
nF = length(uniqueFreqs);

% Initialize 4D Matrix: [Subjects x Contrast x Light x Freq]
discomfortMatrix = nan(nTotalSub, nC, nL, nF);

% Fill the matrix
groups = {'Migraine', 'Control'};
subCounter = 0;

for groupIdx = 1:length(groups)
    grp = groups{groupIdx};
    subList = fieldnames(results.(grp));
    for subjIdx = 1:length(subList)
        subCounter = subCounter + 1;
        for lightIdx = 1:nL
            ndField = matlab.lang.makeValidName(['ND_', NDLabel{lightIdx}]);
            data = results.(grp).(subList{subjIdx}).(ndField);

            for contrastIdx = 1:nC
                for freqIdx = 1:nF
                    % Match frequency and contrast with tolerance
                    idx = (abs(data.frequency - uniqueFreqs(freqIdx)) < 0.01) & ...
                        (abs(data.contrast - uniqueContrasts(contrastIdx)) < 0.01);

                    if any(idx)
                        discomfortMatrix(subCounter, contrastIdx, lightIdx, freqIdx) = mean(data.ratings(idx));
                    end
                end
            end
        end
    end
end

% Create Factor Indices using ndgrid
[S_idx, C_idx, L_idx, F_idx] = ndgrid(1:nTotalSub, 1:nC, 1:nL, 1:nF);

% Create Group Vector (1 = Migraine, 2 = Control)
G_idx = ones(nTotalSub, nC, nL, nF);
G_idx((nMigraine+1):end, :, :, :) = 2;

% Set up Nesting: Subject (1) is nested within Group (2)
% Factors: {Subject, Group, Contrast, Light, Frequency}
nest = zeros(5, 5);
nest(1, 2) = 1;

% Prepare inputs for anovan
factors = {S_idx(:), G_idx(:), C_idx(:), L_idx(:), F_idx(:)};
varnames = {'Subject', 'Group', 'Contrast', 'LightLevel', 'Frequency'};

% Using 'interaction' model to save computation time (omits 4+ way interactions)
[p, tbl, stats] = anovan(discomfortMatrix(:), factors, ...
    'nested', nest, ...
    'random', 1, ...
    'model', 'interaction', ...
    'varnames', varnames);

% Display Summary Table
T_stats = table(G_idx(:), C_idx(:), L_idx(:), F_idx(:), discomfortMatrix(:), ...
    'VariableNames', {'Group', 'Contrast', 'Light', 'Freq', 'Rating'});
end