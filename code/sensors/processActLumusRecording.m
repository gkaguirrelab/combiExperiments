function [xHours,totalIrradianceVec,activityVec]=processActLumusRecording(subjectID,sessionDate,varargin)

%{
subjectID = 'HERO_gka1';
sessionDate = '29-03-2023';
processActLumusRecording(subjectID,sessionDate);
%}

% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('dropBoxBaseDir',getpref('combiLEDToolbox','dropboxBaseDir'),@ischar);
p.addParameter('projectName','combiLED',@ischar);
p.addParameter('approachName','environmentalSampling',@ischar);
p.parse(varargin{:})


% Path to the data
dataDir = fullfile(p.Results.dropBoxBaseDir,...
    'MELA_data',...
    p.Results.projectName,...
    p.Results.approachName,...
    subjectID,sessionDate);

analysisDir = fullfile(p.Results.dropBoxBaseDir,...
    'MELA_analysis',...
    p.Results.projectName,...
    p.Results.approachName,...
    subjectID,sessionDate);

% If the analysisDir does not exist, create it
if ~isfolder(analysisDir)
    mkdir(analysisDir);
end

% Find the actLumus text file
fileList =dir(fullfile(dataDir,'Log*.txt'));

% Make sure we only found one file
assert(length(fileList)==1);

% Load the data table
filename = fullfile(fileList(1).folder,fileList(1).name);
T=readtable(filename,'FileType','text','NumHeaderLines',31,'ReadRowNames',true);

% Find the first event
startIdx = find(T.EVENT==1,1);

% Extract 4 * 5 minutes and 20 seconds.
nSamples = 4*3200/2;
totalIrradianceVec = T.LIGHT(startIdx:startIdx+nSamples);
activityVec = T.TATn(startIdx:startIdx+nSamples);
deltaHour = 2/60/60;
xHours = 0:deltaHour:(nSamples*2/60/60);


end