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
MIDAS = zeros(2,2);
MIDAS(1,1) = NaN; % leave controls blank
MIDAS(1,2) = NaN;
MIDAS(2,1) = mean(poemT.MIDAS_score(poemT.Migraine == 1), 'omitnan');
MIDAS(2,2) = std(poemT.MIDAS_score(poemT.Migraine == 1), 'omitnan');

% Summarize CHYPS score and subscores
vars = { ...
    'CHYPS', ...
    'CHYPS_Brightness', ...
    'CHYPS_Pattern', ...
    'CHYPS_Strobing', ...
    'CHYPS_IntenseVisEnviro'};

CHYPS = nan(2,2,length(vars));

ctrlIdx = (poemT.Migraine == 0);
migIdx  = (poemT.Migraine == 1);

for vv = 1:length(vars)
    ff = vars{vv};

    % Control
    CHYPS(1,1,vv) = mean(poemT.(ff)(ctrlIdx), 'omitnan');
    CHYPS(1,2,vv) = std( poemT.(ff)(ctrlIdx), 'omitnan');

    % Migraine
    CHYPS(2,1,vv) = mean(poemT.(ff)(migIdx), 'omitnan');
    CHYPS(2,2,vv) = std( poemT.(ff)(migIdx), 'omitnan');
end

end