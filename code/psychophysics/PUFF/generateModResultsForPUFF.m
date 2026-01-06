function generateModResultsForPUFF(subjectID,observerAgeInYears,varargin)
% Generate modResult files for the light-puff rig. We wish to have a common
% background for LF, Mel, LMS, and S-directed modulations. The
% backgroundPrimaryHeadroomUb is set so that all modulations (including LF)
% will be able to achieve at least 40% contrast on targeted photoreceptors.
%
% Examples:
%{
    subjectID = 'TEST_001';
    observerAgeInYears = 55;
    experimentName = 'modulate';
    generateModResultsForPUFF(subjectID,observerAgeInYears,'experimentName',experimentName);
%}

% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('dropBoxBaseDir',getpref('combiExperiments','dropboxBaseDir'),@ischar);
p.addParameter('dropBoxSubDir','BLNK_data',@ischar);
p.addParameter('projectName','puffLight',@ischar);
p.addParameter('experimentName','modulate',@ischar);
p.addParameter('primaryHeadRoom',0,@isnumeric);
p.addParameter('backgroundPrimaryHeadroomUb',0.2875,@isnumeric);
p.addParameter('backgroundPrimaryX0',...
    [0.2000    0.2838    0.2000    0.5000    0.2000    0.5003    0.5373    0.4971]',@isnumeric);
p.addParameter('minPhotoreceptorContrast',0.4,@isnumeric);

p.parse(varargin{:})

%  Pull out of the p.Results structure
primaryHeadRoom = p.Results.primaryHeadRoom;
backgroundPrimaryHeadroomUb = p.Results.backgroundPrimaryHeadroomUb;
backgroundPrimaryX0 = p.Results.backgroundPrimaryX0;

% The diameter of the stimulus field in degrees
fieldSizeDeg = 180;

% Define the calibration files
calSubDir = 'PUFF';
calFileName = 'CombiLED-B_split3mm_lightPuff_ND0.mat';

% The directions for which we will create modulations
modulationDirections = {'Mel','LMS','S_peripheral','LightFlux','LightFlux_neutralBG'};

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
    switch whichDirection
        case 'Mel'
            modResults{dd} = designModulation(whichDirection,photoreceptors,cal,...
                'backgroundPrimary',backgroundPrimaryX0,...
                'backgroundPrimaryHeadroomUb',backgroundPrimaryHeadroomUb,...
                'primaryHeadRoom',primaryHeadRoom,'searchBackground',true);
        case 'LightFlux_neutralBG'
            modResults{dd} = designModulation('LightFlux',photoreceptors,cal,...
                'primaryHeadRoom',0,'searchBackground',false);
        otherwise
            modResults{dd} = designModulation(whichDirection,photoreceptors,cal,...
                'primaryHeadRoom',primaryHeadRoom,'backgroundPrimary',modResults{1}.settingsBackground);
    end
    figHandle = plotModResult(modResults{dd});
    drawnow

    % Check that the contrast on the targeted photoreceptors is at least
    % the required minimum
    achievedContrast = mean(abs(modResults{dd}.contrastReceptorsBipolar(modResults{dd}.meta.whichReceptorsToTarget)));
    assert(achievedContrast >= p.Results.minPhotoreceptorContrast);

    % Define the data directory
    dataDir = fullfile(...
        p.Results.dropBoxBaseDir,...
        p.Results.dropBoxSubDir,...,
        p.Results.projectName,...
        p.Results.experimentName,...
        subjectID);

    % Create the dataDir for the subject
    if ~isfolder(dataDir)
        mkdir(dataDir)
    end

    % Save the mod result and plot
    filename = fullfile(dataDir,['modResult_' whichDirection '.mat']);
    modResult = modResults{dd};
    save(filename,'modResult');
    filename = fullfile(dataDir,['modResult_' whichDirection '.pdf']);
    saveas(figHandle,filename,'pdf')
    close(figHandle)

end

end
