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

% Summarize MIDAS scores
MIDAS_table = zeros(2,2);
MIDAS_table(1,1) = NaN; % leave controls blank
MIDAS_table(1,2) = NaN;
MIDAS_table(2,1) = mean(poemT.MIDAS_score(poemT.Migraine == 1), 'omitnan');
MIDAS_table(2,2) = std(poemT.MIDAS_score(poemT.Migraine == 1), 'omitnan');

% Convert to strings for table
MIDAS = strings(2,1);
MIDAS(1) = "";
MIDAS(2) = sprintf('%.2f ± %.2f', MIDAS_table(2,1), MIDAS_table(2,2));

% Summarize CHYPS score and subscores
vars = { ...
    'CHYPS', ...
    'CHYPS_Brightness', ...
    'CHYPS_Pattern', ...
    'CHYPS_Strobing', ...
    'CHYPS_IntenseVisEnviro'};

CHYPS_matrix = nan(2,2,length(vars));

ctrlIdx = (poemT.Migraine == 0);
migIdx  = (poemT.Migraine == 1);

for vv = 1:length(vars)
    ff = vars{vv};

    % Control
    CHYPS_matrix(1,1,vv) = mean(poemT.(ff)(ctrlIdx), 'omitnan');
    CHYPS_matrix(1,2,vv) = std( poemT.(ff)(ctrlIdx), 'omitnan');

    % Migraine
    CHYPS_matrix(2,1,vv) = mean(poemT.(ff)(migIdx), 'omitnan');
    CHYPS_matrix(2,2,vv) = std( poemT.(ff)(migIdx), 'omitnan');
end

% Convert to strings for table
CHYPS_total = CHYPS_matrix(:,:,1);
CHYPS = strings(2,1);
for ii = 1:2
    CHYPS(ii) = sprintf('%.2f ± %.2f', CHYPS_total(ii,1), CHYPS_total(ii,2));
end

end