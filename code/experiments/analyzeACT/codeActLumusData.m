% This file codes the ActLumus data in order to randomly assign the 
% subject IDs to letters of the alphabet, renaming the files so that 
% we cannot identify control vs migraine participants when analyzing the data.

% Define directories
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir = 'FLIC_data';
projectName = 'actLumus';
experimentName = 'data files';

dataDir = fullfile(dropBoxBaseDir, dropBoxSubDir, projectName, experimentName);

% Create output directory
outDir = fullfile(dropBoxBaseDir, dropBoxSubDir, projectName, 'anonymized data files');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

% Get list of all .txt files in directory
files = dir(fullfile(dataDir, '*.txt'));

% Keep only files that contain "FLIC" in the name
files = files(contains({files.name}, 'FLIC'));

% Extract filenames
fileNames = {files.name};

% Create random permutation of letters (A, B, C, ...)
nFiles = numel(fileNames);
letters = char('A' + (0:nFiles-1))';
letters = cellstr(letters);

randIdx = randperm(nFiles);
shuffledLetters = letters(randIdx);

% Optional: store mapping for reproducibility
mapping = table(fileNames', shuffledLetters, ...
    'VariableNames', {'OriginalFile','AnonID'});

save(fullfile(outDir, 'anonymization_mapping.mat'), 'mapping');

% Loop through files, copy and rename
for i = 1:nFiles
    oldName = fileNames{i};
    oldPath = fullfile(dataDir, oldName);

    % Extract date portion (assumes last 8 digits before .txt like YYYYMMDD)
    tokens = regexp(oldName, '(\d{8})\.txt$', 'tokens');
    if ~isempty(tokens)
        dateStr = tokens{1}{1};
    else
        dateStr = 'unknownDate';
    end

    newName = sprintf('%s-%s.txt', shuffledLetters{i}, dateStr);
    newPath = fullfile(outDir, newName);

    copyfile(oldPath, newPath);
end
