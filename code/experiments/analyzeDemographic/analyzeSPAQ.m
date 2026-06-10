function gssSummary = analyzeSPAQ(participantList, dataDir)

% Calculate the GSS score from the SPAQ
% Sum of the 6 items on the question: To what degree do the following change with the seasons?
% Length of sleep, social activity, mood (overall well being), weight, ...
% appetite, energy level 
% Gives a score from 0 (no seasonality) to 24 (extreme seasonality)

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