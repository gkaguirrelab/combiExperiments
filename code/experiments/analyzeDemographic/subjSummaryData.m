% This code generates tables of FLIC demographic and clinical characteristics.

% Define directories
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir = 'FLIC_analysis';
dropBoxSummaryDir = 'FLIC_subject'; % for subjSummary spreadsheet only
projectName = 'dichopticFlicker';
experimentName = 'surveyData';

% Load subj summary excel sheet
subjSummaryDataDir = fullfile(dropBoxBaseDir, dropBoxSummaryDir);
subjSummaryFile = fullfile(subjSummaryDataDir,'/FLIC_SubjectSummary.xlsx'); 
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
% Remove subjects who did not participate (have a star next to ID)
hasStar = contains(subjSummaryT.SubjectID, '*');
subjSummaryT = subjSummaryT(~hasStar, :);
% Convert text columns to string arrays
subjSummaryT.MigraineOrControl_ = string(subjSummaryT.MigraineOrControl_);
subjSummaryT.SexAssignedAtBirth = string(subjSummaryT.SexAssignedAtBirth);
subjSummaryT.NIHRace = string(subjSummaryT.NIHRace);
subjSummaryT.NIHEthnicity = string(subjSummaryT.NIHEthnicity);
% Sort order to be migrainers -> control subjects in increasing order
subjSummaryT.idNum = str2double(extractAfter(subjSummaryT.SubjectID,"FLIC_"));
subjSummaryT = sortrows(subjSummaryT, {'MigraineOrControl_','idNum'});
subjSummaryT.idNum = []; % remove temp variable

% Load POEM data excel sheet
poemDataDir = fullfile(dropBoxBaseDir, dropBoxSubDir, projectName, experimentName);
poemFile = fullfile(poemDataDir,'/POEM_subjID_only.xlsx'); 
% Process this spreadsheet with code from POEM_analysis repo
preProcessT = poemAnalysis_preProcess_v3(poemFile);
poemT = poemAnalysis_classify_v3(preProcessT);
% Sort order to be migrainers -> control subjects in increasing order
poemT.idNum = str2double(extractAfter(poemT{:,1},"FLIC_"));
poemT = sortrows(poemT, {'Migraine','idNum'});
poemT.idNum = []; % remove temp variable

%% 
% This subject makes a table with: 
% Info stratified by group includes no of women, age, headache days/1 mo,
% CHYPS score, MIDAS score, medication use last month

% Extracting no of women and age from subjSummary doc
% Extracting headache days and MIDAS from POEM
% Have not added in medication use yet

groups = {'Control','Migraine with aura'};

% Compute age summary
age_summary = strings(length(groups),1);
for i = 1:length(groups)
    idx = subjSummaryT.MigraineOrControl_ == groups{i};
    mean_age = mean(subjSummaryT.Age(idx));
    std_age = std(subjSummaryT.Age(idx));
    age_summary(i) = sprintf('%.1f ± %.1f', mean_age, std_age);
end

% Compute number of women
sex_summary = strings(length(groups),1);
for i = 1:length(groups)
    idx = subjSummaryT.MigraineOrControl_ == groups{i};
    n_women = sum(subjSummaryT.SexAssignedAtBirth(idx) == "Female");
    n_total = sum(idx);
    sex_summary(i) = sprintf('%d/%d', n_women, n_total);
end

% Clinical variables to summarize (mean ± SD)
varNames = { ...
    'MonthlyMigraineFrequency', ...
    'MIDAS_score', ...
    'CHYPS_total_score', ...
    'CHYPS_Brightness', ...
    'CHYPS_Pattern', ...
    'CHYPS_Strobing', ...
    'CHYPS_IntenseVisEnviro'};

var_summary = strings(length(groups), length(varNames));

for v = 1:length(varNames)
    thisVar = varNames{v};

    for i = 1:length(groups)
        idx = subjSummaryT.MigraineOrControl_ == groups{i};

        data = poemT.(thisVar);
        mean_val = mean(data(idx), 'omitnan');
        std_val  = std(data(idx), 'omitnan');

        var_summary(i,v) = sprintf('%.1f ± %.1f', mean_val, std_val);
    end
end

% Combine into table
summaryTable = table( ...
    groups', ...
    age_summary, ...
    sex_summary, ...
    var_summary(:,1), ...
    var_summary(:,2), ...
    var_summary(:,3), ...
    var_summary(:,4), ...
    var_summary(:,5), ...
    var_summary(:,6), ...
    var_summary(:,7), ...
    'VariableNames', { ...
        'Group', ...
        'Age_mean_SD', ...
        'Female_n_over_total', ...
        'MonthlyMigraineFrequency', ...
        'MIDAS_score', ...
        'CHYPS_total', ...
        'CHYPS_Brightness', ...
        'CHYPS_Pattern', ...
        'CHYPS_Strobing', ...
        'CHYPS_IntenseVisEnviro'});

disp(summaryTable)

% poemT.MonthlyMigraineFrequency;
% poemT.MIDAS_score;
% poemT.CHYPS_total_score;
% poemT.CHYPS_Brightness;
% poemT.CHYPS_Pattern;
% poemT.CHYPS_Strobing;
% poemT.CHYPS_IntenseVisEnviro

%%
% This section makes a table with:
% Information stratified by group includes age, number of women, race
% composition of the sample, and number of hispanic individuals
% Add BCVA and color blindness information, not sure how to summarize

% Compute age summary
groups = {'Control','Migraine with aura'};
age_summary = strings(length(groups),1);

for i = 1:length(groups)
    idx = subjSummaryT.MigraineOrControl_ == groups{i};
    mean_age = mean(subjSummaryT.Age(idx));
    std_age = std(subjSummaryT.Age(idx));
    age_summary(i) = sprintf('%.1f ± %.1f', mean_age, std_age);
end

% Compute number of women
sex_summary = strings(length(groups),1);

for i = 1:length(groups)
    idx = subjSummaryT.MigraineOrControl_ == groups{i};
    n_women = sum(subjSummaryT.SexAssignedAtBirth(idx) == "Female");
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
    race_composition(i) = strjoin(parts(parts ~= ""), ', ');
end

% Ethnicity summary
ethnicity_summary = zeros(length(groups),1);  % just number of Hispanic
for i = 1:length(groups)
    idx = subjSummaryT.MigraineOrControl_ == groups{i};
    ethnicity_summary(i) = sum(subjSummaryT.NIHEthnicity(idx) == "Hispanic or Latino");
end

% Combine into a table
demographics_table = table();
demographics_table.Group = groups';
demographics_table.Age = age_summary;
demographics_table.NumberWomen = sex_summary;
demographics_table.RaceComposition = race_composition;
demographics_table.NumberHispanic = ethnicity_summary;

disp(demographics_table)



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
subjSummaryT = readtable(filename, opts);

% Extract the Age column
ages = [TOld.Age; subjSummaryT.Age];

% Define bin edges
edges = [0 2 6 13 18 26 46 65 76 inf];

% Count individuals in each bin
[counts, ~] = histcounts(ages, edges);

% Labels (for display)
labels = {'0-1', '2-5', '6-12', '13-17', '18-25', '26-45', '46-64', '65-75', '76+'};

% Display results
result_table = table(labels', counts', 'VariableNames', {'AgeGroup','Count'});

disp(result_table);