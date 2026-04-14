% To efficiently process and analyze responses to the POEM survey for our
% DCPT_discrim experiment

fileName = 'POEM_v3.3 -- CHYPS_March 6, 2026_09.22.xlsx';

spreadsheet = ['/Users/melanopsin/Aguirre-Brainard Lab Dropbox/Ruby Bouhassira/FLIC_analysis/dichopticFlicker/surveyData/' fileName];
T = poemAnalysis_preProcess_v3(spreadsheet);

poemAnalysis_classify_v3(T)
 