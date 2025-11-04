% To efficiently process and analyze responses to the POEM survey for our
% DCPT_discrim experiment

fileName = 'POEM_v3.3 -- CHYPS_October 31, 2025_08.13.csv';

spreadsheet = ['/Users/melanopsin/Aguirre-Brainard Lab Dropbox/Ruby Bouhassira/FLIC_subject/POEM raw data files Summer 2025/' fileName];
T = poemAnalysis_preProcess_v3(spreadsheet);

poemAnalysis_classify_v3(T)
 