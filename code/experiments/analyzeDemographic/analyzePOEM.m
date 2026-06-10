function [monthlyMigraineFreq, CHYPS, MIDAS] = analyzePOEM(participantList, dataDir)

% Load POEM data excel sheet
poemFile = fullfile(dataDir,'/POEM_subjID_only.xlsx');

% Process this spreadsheet with code from POEM_analysis repo
% Need to have POEM_analysis repo on Matlab path
preProcessT = poemAnalysis_preProcess_v3(poemFile);
poemT = poemAnalysis_classify_v3(preProcessT);

% Keep only participants in participantList 
poemT = poemT(ismember(string(poemT{:,1}), participantList), :);

% Sort order to be migrainers -> control subjects in increasing order
poemT.idNum = str2double(extractAfter(poemT{:,1},"FLIC_"));
poemT = sortrows(poemT, {'Migraine','idNum'});
poemT.idNum = []; % remove temp variable

% Determine headache types
% Define bins
episodicBins = ["0 - 4 days", "5 - 9 days", "10 - 15 days"];
chronicBins  = ["16 - 20 days", "More than 20 days"];
monthlyMigraineFreq = strings(2,1);
% 0 = Control
ctrlIdx = (poemT.Migraine == 0);
ctrlData = string(poemT.MonthlyMigraineFrequency(ctrlIdx));
ctrlData = ctrlData(~ismissing(ctrlData));
monthlyMigraineFreq(1) = "";
% 1 = Migraine
migIdx = (poemT.Migraine == 1);
migData = string(poemT.MonthlyMigraineFrequency(migIdx));
migData = migData(~ismissing(migData));
episodicCount = sum(ismember(migData, episodicBins));
chronicCount  = sum(ismember(migData, chronicBins));
monthlyMigraineFreq(2) = sprintf( ...
    'Episodic: %d, Chronic: %d', ...
    episodicCount, chronicCount);

% Summarize MIDAS categories for migraine participants
MIDAS = strings(2,1);
MIDAS(1) = ""; % controls blank

midasScores = poemT.MIDAS_score(poemT.Migraine == 1);
midasScores = midasScores(~isnan(midasScores));

nMig = numel(midasScores);

little = sum(midasScores >= 0  & midasScores <= 5);
mild = sum(midasScores >= 6  & midasScores <= 10);
moderate = sum(midasScores >= 11 & midasScores <= 20);
severe = sum(midasScores >= 21);

MIDAS(2) = sprintf([ ...
    'Little/no disability: %d (%.0f%%), ' ...
    'Mild: %d (%.0f%%), ' ...
    'Moderate: %d (%.0f%%), ' ...
    'Severe: %d (%.0f%%)'], ...
    little, 100*little/nMig, ...
    mild, 100*mild/nMig, ...
    moderate, 100*moderate/nMig, ...
    severe, 100*severe/nMig);

% Summarize CHYPS score and subscores
vars = { ...
    'CHYPS', ...
    'CHYPS_Brightness', ...
    'CHYPS_Pattern', ...
    'CHYPS_Strobing', ...
    'CHYPS_IntenseVisEnviro'};

% Dimensions:
% (:,1,:) = median
% (:,2,:) = Q1
% (:,3,:) = Q3
CHYPS_matrix = nan(2,3,length(vars));

ctrlIdx = (poemT.Migraine == 0);
migIdx  = (poemT.Migraine == 1);

for vv = 1:length(vars)
    ff = vars{vv};

    % Control
    ctrlVals = poemT.(ff)(ctrlIdx);
    ctrlVals = ctrlVals(~isnan(ctrlVals));

    CHYPS_matrix(1,1,vv) = median(ctrlVals);
    CHYPS_matrix(1,2,vv) = prctile(ctrlVals,25);
    CHYPS_matrix(1,3,vv) = prctile(ctrlVals,75);

    % Migraine
    migVals = poemT.(ff)(migIdx);
    migVals = migVals(~isnan(migVals));

    CHYPS_matrix(2,1,vv) = median(migVals);
    CHYPS_matrix(2,2,vv) = prctile(migVals,25);
    CHYPS_matrix(2,3,vv) = prctile(migVals,75);
end

% Convert total CHYPS score to strings for table
CHYPS_total = CHYPS_matrix(:,:,1);

CHYPS = strings(2,1);

for ii = 1:2
    CHYPS(ii) = sprintf('%.2f (%.2f–%.2f)', ...
        CHYPS_total(ii,1), ... % median
        CHYPS_total(ii,2), ... % Q1
        CHYPS_total(ii,3));    % Q3
end