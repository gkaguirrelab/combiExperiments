function analyzeFlickerNullExperiment(subjectID,modDirection,modDirectionNulledName,varargin)
% 
%
% Examples:
%{
    subjectID = 'HERO_gka1';
    modDirection = 'LminusM_wide';
    modDirectionNulledName = 'LminusM_LMSNull';
    stimContrast = 0.125;
    analyzeFlickerNullExperiment(subjectID,modDirection,modDirectionNulledName,'stimContrast',stimContrast);
%}
%{
    subjectID = 'HERO_gka1';
    modDirection = 'S_wide';
    modDirectionNulledName = 'S_LMSNull';
    stimContrast = 0.15;
    analyzeFlickerNullExperiment(subjectID,modDirection,modDirectionNulledName,'stimContrast',stimContrast);
%}

% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('dropBoxBaseDir',getpref('combiLEDToolbox','dropboxBaseDir'),@ischar);
p.addParameter('projectName','combiLED',@ischar);
p.addParameter('stimContrast',0.125,@isnumeric);
p.parse(varargin{:})

% Extract this variable
stimContrast = p.Results.stimContrast;

% Set our experimentName
experimentName = 'flickerNull';

% Fix the random seed for reproducibility of boot-strap results
rng(1);

% Define the location of the data
modDir = fullfile(...
    p.Results.dropBoxBaseDir,...
    'MELA_data',...,
    p.Results.projectName,...
    subjectID,modDirection);
dataDir = fullfile(modDir,experimentName);

% Define the analysis directory for the result plot
analysisDir = fullfile(...
    p.Results.dropBoxBaseDir,...
    'MELA_analysis',...,
    p.Results.projectName,...
    subjectID,modDirection,experimentName);

% Create a directory for the subject
if ~isfolder(analysisDir)
    mkdir(analysisDir)
end

% Load the measurement record
filesuffix = ['_' subjectID '_' modDirectionNulledName '_' experimentName ...
    sprintf('_cntrst-%2.2f',stimContrast) ];
filename = fullfile(dataDir,['measurementRecord' filesuffix '.mat']);
load(filename,'measurementRecord');

% Extract some variables
nStims = measurementRecord.experimentProperties.nStims;

% Load the psychometric objects
sessionData = struct();
for ii=1:nStims
    if mod(ii,2)==0
        searchDirection = 'adjustHighSettings';
    else
        searchDirection = 'adjustLowSettings';
    end

    sessionData.fileStem{ii} = [subjectID '_' modDirectionNulledName '_' experimentName ...
        sprintf('_cntrst-%2.2f',stimContrast) '_' searchDirection];

    % Load the psychometric objects
    filename = fullfile(dataDir,[sessionData.fileStem{ii} '.mat']);
    if isfile(filename)
        tmpObj = load(filename,'psychObj');
        sessionObj{ii} = tmpObj.psychObj;
        clear tmpObj
    end
end

% Combine all of the trials across objects in a single object,
% and re-fit
comboObj = sessionObj{1};
for ii=2:nStims
    comboObj.questData.trialData = ...
        [comboObj.questData.trialData; sessionObj{ii}.questData.trialData];
    comboObj.questData.stimIndices = ...
        [comboObj.questData.stimIndices; sessionObj{ii}.questData.stimIndices];
    comboObj.questData.entropyAfterTrial = ...
        [comboObj.questData.entropyAfterTrial; sessionObj{ii}.questData.entropyAfterTrial];

end

% Plot
figHandle = comboObj.plotOutcome('off');
filestem = [subjectID '_' modDirectionNulledName '_' experimentName ...
    sprintf('_cntrst-%2.2f',stimContrast)];
filename = fullfile(analysisDir,[filestem '.pdf']);
saveas(figHandle,filename,'pdf')

% Get the average adjustment
[~, psiParamsFit] = comboObj.reportParams();

% Create the nulled modResult
modResult = comboObj.returnAdjustedModResult(psiParamsFit(1));

% A new directory in the data directory for the nulled modulation
nulledModDir = fullfile(...
    p.Results.dropBoxBaseDir,...
    'MELA_data',...,
    p.Results.projectName,...
    subjectID,modDirectionNulledName);

% Create a directory for the subject
if ~isfolder(nulledModDir)
    mkdir(nulledModDir)
end

% Save the nulled modResult both in the analysis directory, and as a
% modulation direction to be used in the data directory
filename = fullfile(nulledModDir,'modResult.mat');
save(filename,'modResult');
filename = fullfile(analysisDir,'modResultNulled.mat');
save(filename,'modResult');
figHandle = plotModResult(modResult,'off');
filename = fullfile(nulledModDir,'modResult.pdf');
saveas(figHandle,filename,'pdf')
filename = fullfile(analysisDir,'modResultNulled.pdf');
saveas(figHandle,filename,'pdf')
close(figHandle)

end
