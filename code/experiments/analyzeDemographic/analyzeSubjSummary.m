function [ageSummary, sexSummary, ethnicitySummary, raceSummary] = analyzeSubjSummary(participantList, dataDir)

% Load subj summary excel sheet
subjSummaryFile = fullfile(dataDir,'/FLIC_SubjectSummary.xlsx'); 

% Detect the default options for this file
opts = detectImportOptions(subjSummaryFile);

% Set where the Variable Names (titles) and Data start
% Headers are in Row 1 and data starts in Row 2:
opts.VariableNamesRange = 'A1'; 
opts.DataRange = 'A2';

% Read the Excel file into a table
subjSummaryT = readtable(subjSummaryFile, opts);

% Rename variables to clean names
subjSummaryT = renamevars(subjSummaryT, {'SubjectID__'},{'SubjectID'});

% Last subject is FLIC_0051, want the table to end here
idx_end = find(strcmp(subjSummaryT.SubjectID, 'FLIC_0051'));
subjSummaryT = subjSummaryT(1:idx_end, :);

% Keep only subjects in participantList
subjSummaryT = subjSummaryT(ismember(subjSummaryT.SubjectID, participantList), :);

% Convert text columns to string arrays
subjSummaryT.MigraineOrControl_ = string(subjSummaryT.MigraineOrControl_);
subjSummaryT.SexAssignedAtBirth = string(subjSummaryT.SexAssignedAtBirth);
subjSummaryT.NIHRace = string(subjSummaryT.NIHRace);
subjSummaryT.NIHEthnicity = string(subjSummaryT.NIHEthnicity);

% Sort order to be migrainers -> control subjects in increasing order
subjSummaryT.idNum = str2double(extractAfter(subjSummaryT.SubjectID,"FLIC_"));
subjSummaryT = sortrows(subjSummaryT, {'MigraineOrControl_','idNum'});
subjSummaryT.idNum = []; % remove temp variable

groups = {'Control','Migraine'};
tableGroups = {'Control', 'Migraine with aura'}; % longer names for table

% Compute age summary
ageSummary = strings(length(groups),1);
for i = 1:length(groups)
    idx = subjSummaryT.MigraineOrControl_ == groups{i};
    med_age = median(subjSummaryT.Age(idx));
    q1_age = prctile(subjSummaryT.Age(idx),25);
    q3_age = prctile(subjSummaryT.Age(idx),75);
    ageSummary(i) = sprintf('%.1f (%.1f–%.1f)', ...
        med_age, q1_age, q3_age);
end

% Compute number of women
sexSummary = strings(length(groups),1);
for i = 1:length(groups)
    idx = subjSummaryT.MigraineOrControl_ == groups{i};
    n_women = sum(subjSummaryT.SexAssignedAtBirth(idx) == "Female");
    n_total = sum(idx);
    sexSummary(i) = sprintf('%d/%d', n_women, n_total);
end

% Ethnicity summary
ethnicitySummary = zeros(length(groups),1);  % just number of Hispanic
for i = 1:length(groups)
    idx = subjSummaryT.MigraineOrControl_ == groups{i};
    ethnicitySummary(i) = sum(subjSummaryT.NIHEthnicity(idx) == "Hispanic or Latino");
end

% Race composition
race_categories = [   % NIH race categories
    "White"
    "Black or African American"
    "Asian"
    "American Indian or Alaska Native"
    "Native Hawaiian or Other Pacific Islander"
];
raceSummary = strings(length(groups),1);

for i = 1:length(groups)
    idx = subjSummaryT.MigraineOrControl_ == groups{i};
    n_total = sum(idx);
    parts = strings(1, length(race_categories));
    for j = 1:length(race_categories)
        n_race = sum(contains(subjSummaryT.NIHRace(idx), race_categories(j)));
        pct = round(100 * n_race / n_total);
        if n_race > 0
            parts(j) = sprintf('%s %d (%d%%)', race_categories(j), n_race, pct);
        else
            parts(j) = "";
        end
    end
    % Join non-empty parts with commas
    raceSummary(i) = strjoin(parts(parts ~= ""), ', ');
end


end