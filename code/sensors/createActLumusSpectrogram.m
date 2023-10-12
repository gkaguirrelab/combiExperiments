function []=createActLumusSpectrogram(subjectID,sessionDate,varargin)

%{
subjectID = 'HERO_gka1';
sessionDate = '29-03-2023';
createActLumusSpectrogram(subjectID,sessionDate);
%}

% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('dropBoxBaseDir',getpref('combiLEDToolbox','dropboxBaseDir'),@ischar);
p.addParameter('projectName','combiLED',@ischar);
p.addParameter('approachName','environmentalSampling',@ischar);
p.addParameter('windowDurSecs',100,@isnumeric);
p.addParameter('windowStepSecs',25,@isnumeric);
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

 % Step through the recording. For each window, obtain set of spectral
 % weights. Convert these to post-receptoral cone directions. Obtain the
 % temporal spectral distribution
idx = startIdx;
nSamples = p.Results.windowDurSecs / 2;
while idx < (size(T)-nSamples)
    weightMat = cell2mat(cellfun(@(x) T.(x)(idx:idx+nSamples-1),channelNames,'UniformOutput',false));
    coneVec = actLumusToCones(weightMat);
end


end