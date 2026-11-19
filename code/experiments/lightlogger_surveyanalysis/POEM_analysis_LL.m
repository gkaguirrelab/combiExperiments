% To efficiently process and analyze responses to the POEM survey for our
% DCPT_discrim experiment
poemDir = fullfile(tbLocateProject('poemAnalysis'));
addpath(genpath(poemDir));

% change path name
spreadsheet = '/Users/jmatin/Library/CloudStorage/Box-Box/FLIC_protected/Scripted Indoor Outdoor/RawSurveyResponses/POEM_v3.3 -- CHYPS_November 13, 2026_07.17.xlsx';
T = poemAnalysis_preProcess_v3(spreadsheet);

poemAnalysis_classify_v3(T)

%% run this to save results (then append results to existing spreadsheet and delete new.xlsx)
save_file = '/Users/jmatin/Library/CloudStorage/Box-Box/FLIC_protected/Scripted Indoor Outdoor/new.xlsx';
writetable(ans, save_file);