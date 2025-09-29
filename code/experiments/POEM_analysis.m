% To efficiently process and analyze responses to the POEM survey for our
% DCPT_discrim experiment

fileName = 'POEM_v3.3 -- CHYPS_September 29, 2025_08.21.csv';

spreadsheet = ['/Users/rubybouh/Aguirre-Brainard Lab Dropbox/Ruby Bouhassira/FLIC_subject/POEM raw data files Summer 2025/' fileName];
T = poemAnalysis_preProcess_v3(spreadsheet);

poemAnalysis_classify_v3(T)
