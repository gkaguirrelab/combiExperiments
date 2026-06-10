% Do an unpaired t test on the median Lux*hrs of daytime light exposure 
% for our 20 participants in the ActLumus recordings
% Is there a difference between the groups? No significant difference found

clear all;
close all; 

% Define directories for the anonymized mapping file and lux data file
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');
codeDir = 'FLIC_data/actLumus/anonymized data files/';
luxDir = 'FLIC_analysis/actLumus/';

codeName = 'anonymization_mapping.mat';
luxName = 'actLumus_daytimeLightExposure';

% Pull the anonymized mapping file
codeFile = load(fullfile(dropBoxBaseDir, codeDir, codeName), 'mapping');

% Pull the lux file
luxData = readtable(fullfile(dropBoxBaseDir, luxDir, luxName)); 

% Convert anonymized IDs back to subject IDs (e.g. FLIC_0001)
mapping = codeFile.mapping;

% Ensure strings for easier handling
luxData.ID = string(luxData.ID);
mapping.AnonID = string(mapping.AnonID);
mapping.OriginalFile = string(mapping.OriginalFile);
% Remove .txt from the mapping table
codeFile.mapping.OriginalFile = erase(string(codeFile.mapping.OriginalFile), ".txt");

anonIDs = extractBefore(string(luxData.ID), "-");

for ii = 1:height(luxData)

    % e.g. pull "A" from the list, find the row of mapping
    % where AnonID is "A"
    idx = strcmp(codeFile.mapping.AnonID, anonIDs(ii));

    % Replace the entry with the corresponding OriginalFile
    if any(idx)
        luxData.ID(ii) = codeFile.mapping.OriginalFile(idx);
    end

end

% Make sure IDs are strings
IDs = string(luxData.ID);

% Control or migraine group? 
participantCode = extractAfter(IDs, "FLIC_");

isControl = startsWith(participantCode, "0");
isMigraine = startsWith(participantCode, "1");

% Extract MedianLux_hr values
controlLux = luxData.MedianLux_hr(isControl);
migraineLux = luxData.MedianLux_hr(isMigraine);

% Checking assumptions
figure;
histogram(controlLux, 'BinWidth', 2000);
xlim([0 15000]);
ylim([0 4]);
xlabel('Median daytime light exposure (lux*hr)');
ylabel('Count');
title('Control');
figure;
histogram(migraineLux, 'BinWidth', 2000);
xlim([0 15000]);
ylim([0 4]);
xlabel('Median daytime light exposure (lux*hr)');
ylabel('Count');
title('Migraine');

% Unpaired (two-sample) t-test
[h,p,ci,stats] = ttest2(controlLux, migraineLux);

fprintf('Control: n=%d, mean=%.2f\n', ...
    numel(controlLux), mean(controlLux));

fprintf('Migraine: n=%d, mean=%.2f\n', ...
    numel(migraineLux), mean(migraineLux));

fprintf('t(%0.1f) = %.3f, p = %.4f\n', ...
    stats.df, stats.tstat, p);

% Wilcoxon rank-sum test instead, since not normally distributed
[p,h,stats] = ranksum(controlLux, migraineLux);

fprintf('rank-sum z = %.3f, p = %.4f\n', stats.zval, p);