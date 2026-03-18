% This code creates a demographic table from the FLIC subject summary Excel spreadsheet.

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