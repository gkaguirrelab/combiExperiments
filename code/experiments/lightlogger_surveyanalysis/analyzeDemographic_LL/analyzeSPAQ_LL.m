function gssSummary = analyzeSPAQ_LL(participantList)

% Calculate the GSS score from the SPAQ
% Sum of the 6 items on the question: To what degree do the following change with the seasons?
% Length of sleep, social activity, mood (overall well being), weight, ...
% appetite, energy level 
% Gives a score from 0 (no seasonality) to 24 (extreme seasonality)

% To run: (add new participants to participantList)
%{
participantList = {'FLIC_0028', 'FLIC_0042', 'FLIC_0051', 'FLIC_1047',...
'FLIC_1044', 'FLIC_0021', 'FLIC_0020', 'FLIC_1052', 'FLIC_1051',...
'FLIC_1054', 'FLIC_0054', 'FLIC_0052', 'FLIC_1056', 'FLIC_1058',...
'FLIC_0055', 'FLIC_1062', 'FLIC_1055', 'FLIC_1059', 'FLIC_1063',...
'FLIC_1066', 'FLIC_0056', 'FLIC_0058', 'FLIC_1065', 'FLIC_1067',...
'FLIC_0060', 'FLIC_0057', 'FLIC_1068', 'FLIC_0061'};

analyzeSPAQ_LL(participantList)
%}

dropboxBaseDir = getpref('combiExperiments', 'dropboxBaseDir');
dataDir = fullfile(dropboxBaseDir, '/FLIC_subject/scriptedIndoorOutdoor_2026_photophobia/Survey_Responses');

% Load seasonal sensitivity data
seasonFile = fullfile(dataDir, 'FLIC Seasonal Sensitivity (Responses).xlsx');

% Detect the default options for this file
opts = detectImportOptions(seasonFile);
% Set where the Variable Names (titles) and Data start
% Headers are in Row 1 and data starts in Row 2:
opts.VariableNamesRange = 'A1'; 
opts.DataRange = 'A2';

% Read the Excel file into a table
seasonT = readtable(seasonFile, opts);

% Filter table to include completed subjects only
idx_keep = ismember(seasonT.SubjectID, participantList);
seasonT = seasonT(idx_keep, :);

% Extract the 6 SPAQ columns (as strings)
seasonItems_raw = string(seasonT{:,4:9});

% Initialize numeric matrix
seasonItems_num = nan(size(seasonItems_raw));

% Map text to scores
seasonItems_num(seasonItems_raw == "No Change (0)") = 0;
seasonItems_num(seasonItems_raw == "Slight Change (1)") = 1;
seasonItems_num(seasonItems_raw == "Moderate Change (2)") = 2;
seasonItems_num(seasonItems_raw == "Marked Change (3)") = 3;
seasonItems_num(seasonItems_raw == "Extremely Marked Change (4)") = 4;

% Compute GSS (sum across the 6 items)
seasonT.GSS = sum(seasonItems_num, 2, 'omitnan');

% Extract numeric part after "FLIC_"
idNum = str2double(extractAfter(seasonT.SubjectID, "FLIC_"));

% Define groups 
isMigraine = idNum >= 1000;
isControl  = idNum < 1000;

% Define categories
lowIdx  = seasonT.GSS <= 7;
modIdx  = seasonT.GSS >= 8 & seasonT.GSS <= 10;
highIdx = seasonT.GSS >= 11;

cats = ["Low","Moderate","High"];

gssSummary = strings(2,1);

for g = 1:2

    if g == 1
        idx = isControl;
    else
        idx = isMigraine;
    end

    total = sum(idx);

    if total == 0
        gssSummary(g) = "";
        continue;
    end

    % Counts
    lowN  = sum(lowIdx & idx);
    modN  = sum(modIdx & idx);
    highN = sum(highIdx & idx);

    % Percentages
    lowPct  = 100 * lowN  / total;
    modPct  = 100 * modN  / total;
    highPct = 100 * highN / total;

    % Format: n (%)
    gssSummary(g) = sprintf( ...
        'Low: %d (%.1f%%), Moderate: %d (%.1f%%), High: %d (%.1f%%)', ...
        lowN, lowPct, modN, modPct, highN, highPct);
end

end