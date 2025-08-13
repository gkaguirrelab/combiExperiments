function generateModResultsForPUFF(subjectID,observerAgeInYears,varargin)
% We pre-generate the modResult files that define the L–M and LightFlux
% modulations for each subject for the dichoptic rig exoeriments
%
% Examples:
%{
    subjectID = 'HERO_gka';
    observerAgeInYears = 55;
    generateModResultsForPUFF(subjectID,observerAgeInYears);
%}

% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('dropBoxBaseDir',getpref('combiExperiments','dropboxBaseDir'),@ischar);
p.addParameter('projectName','puffLight',@ischar);
p.addParameter('primaryHeadRoom',0.05,@isnumeric); % Leave some space for nulling
p.parse(varargin{:})

%  Pull out of the p.Results structure
primaryHeadRoom = p.Results.primaryHeadRoom;

% Define our DropBox subdirectory and cal file subdirectory
dropBoxSubDir = 'BLNK_data';
calSubDir = 'PUFF';

% The diameter of the stimulus field in degrees
fieldSizeDeg = 30;

% Define the calibration files
calFileName = 'tempFakeCalFile.mat';

% The directions for which we will create modulations
modulationDirections = {'Mel','LightFlux'};

% Load the cal file
cal = loadCalByName(calFileName, calSubDir);

% Get the luminance of the half-on background for this cal file
% Load the XYZ fundamentals
load('T_xyz1931.mat','T_xyz1931','S_xyz1931');
S = cal.rawData.S;
T_xyz = SplineCmf(S_xyz1931,683*T_xyz1931,S);
xyYLocus = XYZToxyY(T_xyz);
backgroundSPD = cal.processedData.P_device * repmat(0.5,8,1);
luminanceCdM2 = T_xyz(2,:)*backgroundSPD;

% Calculate the pupil size
pupilDiameterMm = wy_getPupilSize(observerAgeInYears, luminanceCdM2, fieldSizeDeg, 1, 'Unified');

% Get these photoreceptors
photoreceptors = photoreceptorDictionaryHuman('observerAgeInYears',observerAgeInYears,'pupilDiameterMm',pupilDiameterMm);

% Loop over the modulation directions
for dd = 1:length(modulationDirections)

    % Create the modulation
    whichDirection = modulationDirections{dd};
    if dd == 1
        modResults{dd} = designModulation(whichDirection,photoreceptors,cal,...
            'primaryHeadRoom',primaryHeadRoom,'searchBackground',true);
    else
        modResults{dd} = designModulation(whichDirection,photoreceptors,cal,...
            'primaryHeadRoom',0);
    end
    figHandle = plotModResult(modResults{dd});
    drawnow

    % Define the data directory
    modDir = fullfile(...
        p.Results.dropBoxBaseDir,...
        dropBoxSubDir,...,
        p.Results.projectName,...
        subjectID,whichDirection);

    % Create the modDir for the subject
    if ~isfolder(modDir)
        mkdir(modDir)
    end

    % Save the mod result and plot
    filename = fullfile(modDir,'modResult.mat');
    modResult = modResults{dd};
    save(filename,'modResult');
    filename = fullfile(modDir,'modResult.pdf');
    saveas(figHandle,filename,'pdf')
    close(figHandle)

end

end
