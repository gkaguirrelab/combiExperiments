function vssSummary = analyzeVSQ(participantList, dataDir)

% Load visual snow data
snowFile = fullfile(dataDir, 'FLIC Visual Snow Questionnaire (Responses).xlsx');

% Detect the default options for this file
opts = detectImportOptions(snowFile);

% Set where the Variable Names (titles) and Data start
% Headers are in Row 1 and data starts in Row 2:
opts.VariableNamesRange = 'A1'; 
opts.DataRange = 'A2';

% Read the Excel file into a table
snowT = readtable(snowFile, opts);

% Determine visual snow diagnoses
% Filter to completed subjects only
idx_keep = ismember(snowT.SubjectID, subjectIDs);
snowT = snowT(idx_keep, :);

% Determine migraine or control
ids = string(snowT.SubjectID);
idNum = str2double(extractAfter(ids, "FLIC_"));
isMigraine = idNum >= 1000;
isControl  = idNum < 1000;

% Extract responses
snowResp = string(table2cell(snowT(:,2:end)));

% Helper functions to code responses
isNever = @(x) contains(x,"Never");
isLowFreq = @(x) ...
    contains(x,"Never") | ...
    contains(x,"few times per month") | ...
    contains(x,"few times per week");
isHighFreq = @(x) ...
    contains(x,"Daily") | ...
    contains(x,"All the time") | ...
    contains(x,"every day");

% Mapping column blocks to questions
flick_freq = string(snowT{:,3});  % flickering dots
after_freq = string(snowT{:,6});  % afterimages
trail_freq = string(snowT{:,9});  % trails 
float_freq = string(snowT{:,12}); % floaters   
photo_freq = string(snowT{:,21}); % light sensitivity  
night_freq = string(snowT{:,24}); % trouble seeing in dark

end