function addRedGreenModResultForPUFF(subjectID,varargin)
% Generate modResult files for the light-puff rig. We wish to have a common
% background for LF, Mel, LMS, and S-directed modulations. The
% backgroundPrimaryHeadroomUb is set so that all modulations (including LF)
% will be able to achieve at least 40% contrast on targeted photoreceptors.
%
% Examples:
%{
    subjectID = 'BLNK_1001';
    addRedGreenModResultForPUFF(subjectID);
%}

% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('dropBoxBaseDir',getpref('combiExperiments','dropboxBaseDir'),@ischar);
p.addParameter('dropBoxSubDir','BLNK_data',@ischar);
p.addParameter('projectName','puffLight',@ischar);
p.addParameter('experimentName','modulate',@ischar);
p.addParameter('primaryHeadRoom',0,@isnumeric);
p.addParameter('minPhotoreceptorContrast',0.1,@isnumeric);
p.addParameter('contrastMatchConstraint',1,@isnumeric);
p.parse(varargin{:})


% Define the data directory
dataDir = fullfile(...
    p.Results.dropBoxBaseDir,...
    p.Results.dropBoxSubDir,...,
    p.Results.projectName,...
    p.Results.experimentName,...
    subjectID);

% Load the mel mod result
whichDirection = 'Mel';
filename = fullfile(dataDir,['modResult_' whichDirection '.mat']);
load(filename,'modResult');

% Extract some items and clear the mel mod result
backgroundPrimary = modResult.settingsBackground;
photoreceptors = modResult.meta.photoreceptors;
cal = modResult.meta.cal;
clear modResult

% Create the new mod direction
whichDirection = 'LminusM_MelSilent_peripheral';
modResult = designModulation(whichDirection,photoreceptors,cal,...
    'primaryHeadRoom',p.Results.primaryHeadRoom,...
    'backgroundPrimary',backgroundPrimary,...
    'contrastMatchConstraint',p.Results.contrastMatchConstraint);
figHandle = plotModResult(modResult);

% Check that the contrast on the targeted photoreceptors is at least
% the required minimum
achievedContrast = mean(abs(modResult.contrastReceptorsBipolar(modResult.meta.whichReceptorsToTarget)));
assert(achievedContrast >= p.Results.minPhotoreceptorContrast);

% Save the mod result and plot
filename = fullfile(dataDir,['modResult_' whichDirection '.mat']);
save(filename,'modResult');
filename = fullfile(dataDir,['modResult_' whichDirection '.pdf']);
saveas(figHandle,filename,'pdf')
close(figHandle)

end
