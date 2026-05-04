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
idx_keep = ismember(snowT.SubjectID, participantList);
snowT = snowT(idx_keep, :);

% Determine migraine or control
ids = string(snowT.SubjectID);
idNum = str2double(extractAfter(ids, "FLIC_"));
isMigraine = idNum >= 1000;
isControl  = idNum < 1000;

% Extract responses
snowResp = string(table2cell(snowT(:,2:end)));

% Mapping column blocks to questions
flick_freq = str2double(extractBefore(string(snowT{:,3}), " ")); % flickering dots
after_freq = str2double(extractBefore(string(snowT{:,6}), " ")); % afterimages
trail_freq = str2double(extractBefore(string(snowT{:,9}), " ")); % trails 
float_freq = str2double(extractBefore(string(snowT{:,12}), " ")); % floaters
photo_freq = str2double(extractBefore(string(snowT{:,21}), " ")); % light sensitivity
night_freq = str2double(extractBefore(string(snowT{:,24}), " ")); % trouble seeing in dark

% Define thresholds
isNever    = @(x) x == 0;  % 0 - never
isAny      = @(x) x >= 1;  % 1 - rarely
isWeekly   = @(x) x >= 2;  % 2 - often 
isDaily    = @(x) x >= 3;  % 3 - very often, 4 - all the time

% Scoring responses
% Core visual snow percept
vsEpisodic = isAny(flick_freq);   % any frequency
vsConstant = flick_freq == 4;     % all the time ONLY

% Additional symptoms
afterimage = isDaily(after_freq); % ≥ daily
trail = isDaily(trail_freq);
float = isDaily(float_freq);
night = isDaily(night_freq);

photo = isWeekly(photo_freq);   % ≥ weekly

% Count additional symptoms
additionalCount = afterimage + trail + float + night + photo; 

% Classify groups
group = strings(length(participantList),1);

group(~vsEpisodic & ~vsConstant) = "Control";
group(vsEpisodic & ~vsConstant) = "Group 1 (Episodic VS)";
group(vsConstant & additionalCount < 2) = "Group 2 (VS)";
group(vsConstant & additionalCount >= 2) = "Group 3 (VSS)";

group = categorical(group, ...
    ["Control", "Group 1 (Episodic VS)", "Group 2 (VS)", "Group 3 (VSS)"]);
% Table of results - 0 = control, 1 = migraine
vss_table = crosstab(isMigraine, group);

% Convert to strings for table
labels = ["Episodic", "VS", "VSS"];
vssSummary = strings(2,1);
for ii = 1:2  
    parts = strings(1,0);    
    for jj = 1:length(labels)      
        countVal = vss_table(ii, jj+1);  % shift by +1 to skip Control column        
        if countVal > 0
            parts(end+1) = labels(jj) + ": " + string(countVal);
        end        
    end    
    if isempty(parts)
        vssSummary(ii) = "None";
    else
        vssSummary(ii) = strjoin(parts, ", ");
    end    
end

end