% This code creates a demographic table from the FLIC subject summary Excel spreadsheet.

% Information stratified by group includes age, number of women, race
% composition of the sample, and number of hispanic individuals
% Add BCVA and color blindness information, not sure how to summarize

subjSummaryFile = '/Users/melanopsin/Aguirre-Brainard Lab Dropbox/Ruby Bouhassira/FLIC_subject/FLIC_SubjectSummary.xlsx';

% Detect the default options for this file
opts = detectImportOptions(subjSummaryFile);
% Set where the Variable Names (titles) and Data start
% Headers are in Row 1 and data starts in Row 2:
opts.VariableNamesRange = 'A1'; 
opts.DataRange = 'A2';

% Read the Excel file into a table
T = readtable(subjSummaryFile, opts);

% Rename variables to clean names
T = renamevars(T, {'SubjectID__'},{'SubjectID'}); 

% Last subject is FLIC_0051, want the table to end here
idx_end = find(strcmp(T.SubjectID, 'FLIC_0051'));
T = T(1:idx_end, :);

% Remove subjects who did not participate (have a star next to ID)
hasStar = contains(T.SubjectID, '*');
T = T(~hasStar, :);

% Convert text columns to string arrays
T.MigraineOrControl_ = string(T.MigraineOrControl_);
T.SexAssignedAtBirth = string(T.SexAssignedAtBirth);
T.NIHRace = string(T.NIHRace);
T.NIHEthnicity = string(T.NIHEthnicity);

% Compute age summary
groups = {'Control','Migraine'};
age_summary = strings(length(groups),1);

for i = 1:length(groups)
    idx = T.MigraineOrControl_ == groups{i};
    mean_age = mean(T.Age(idx));
    std_age = std(T.Age(idx));
    age_summary(i) = sprintf('%.1f ± %.1f', mean_age, std_age);
end

% Compute number of women
sex_summary = strings(length(groups),1);

for i = 1:length(groups)
    idx = T.MigraineOrControl_ == groups{i};
    n_women = sum(T.SexAssignedAtBirth(idx) == "Female");
    n_total = sum(idx);
    sex_summary(i) = sprintf('%d/%d', n_women, n_total);
end

% Race composition column
race_categories = [   % NIH race categories
    "White"
    "Black or African American"
    "Asian"
    "American Indian or Alaska Native"
    "Native Hawaiian or Other Pacific Islander"
];
race_composition = strings(length(groups),1);

for i = 1:length(groups)
    idx = T.MigraineOrControl_ == groups{i};
    n_total = sum(idx);
    parts = strings(1, length(race_categories));
    for j = 1:length(race_categories)
        n_race = sum(contains(T.NIHRace(idx), race_categories(j)));
        pct = round(100 * n_race / n_total);
        if n_race > 0
            parts(j) = sprintf('%s %d (%d%%)', race_categories(j), n_race, pct);
        else
            parts(j) = "";
        end
    end
    % Join non-empty parts with commas
    race_composition(i) = strjoin(parts(parts ~= ""), ', ');
end

% Ethnicity summary
ethnicity_summary = zeros(length(groups),1);  % just number of Hispanic
for i = 1:length(groups)
    idx = T.MigraineOrControl_ == groups{i};
    ethnicity_summary(i) = sum(T.NIHEthnicity(idx) == "Hispanic or Latino");
end

% Combine into a table
demographics_table = table();
demographics_table.Group = groups';
demographics_table.Age = age_summary;
demographics_table.NumberWomen = sex_summary;
demographics_table.RaceComposition = race_composition;
demographics_table.NumberHispanic = ethnicity_summary;

disp(demographics_table)


%% Subject demographic and clinical characteristics

% Info stratified by group includes no of women, age, headache days/1 mo,
% CHYPS score, MIDAS score, medication use last month

% Have number of women, age, and CHYPS score from subj summary doc

% Need to extract headache days, MIDAS, medication use from POEM


%% Code specifically to make a table of the ages of all FLIC participants 
% (including Fall 2024 data collection)
% This was to report age information to the NIH

close all;
clear all;

% File name
oldFilename = '/Users/rubybouh/Aguirre-Brainard Lab Dropbox/Ruby Bouhassira/FLIC_subject/Fall 2024/FLIC_SubjectSummary_24.xlsx'
filename = '/Users/rubybouh/Aguirre-Brainard Lab Dropbox/Ruby Bouhassira/FLIC_subject/FLIC_SubjectSummary.xlsx';

% Detect the default options for this file (the file from 2024)
optsOld = detectImportOptions(oldFilename);
% Set where the Variable Names (titles) and Data start
% Headers are in Row 1 and data starts in Row 2:
optsOld.VariableNamesRange = 'A1'; 
optsOld.DataRange = 'A2';

% Repeat the process for the newer file
opts = detectImportOptions(filename);
% Set where the Variable Names (titles) and Data start
% Headers are in Row 1 and data starts in Row 2:
opts.VariableNamesRange = 'A1'; 
opts.DataRange = 'A2';

% Read the Excel files into tables
TOld = readtable(oldFilename, optsOld);
T = readtable(filename, opts);

% Extract the Age column
ages = [TOld.Age; T.Age];

% Define bin edges
edges = [0 2 6 13 18 26 46 65 76 inf];

% Count individuals in each bin
[counts, ~] = histcounts(ages, edges);

% Labels (for display)
labels = {'0-1', '2-5', '6-12', '13-17', '18-25', '26-45', '46-64', '65-75', '76+'};

% Display results
result_table = table(labels', counts', 'VariableNames', {'AgeGroup','Count'});

disp(result_table);