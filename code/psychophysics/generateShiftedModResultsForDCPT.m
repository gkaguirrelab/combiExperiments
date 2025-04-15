function generateShiftedModResultsForDCPT(subjectID,observerAgeInYears,NDlabel,varargin)
% Generate modResult files for experiments on the dichoptic rig
%
% Syntax:
%   generateModResultsForDCPT(subjectID,observerAgeInYears,NDlabel,varargin)
%
% Description:
%   We pre-generate the modResult files that define the L–M and LightFlux
%   modulations for each subject for the dichoptic rig exoeriments
%
% Inputs:
%   subjectID             - String.
%   observerAgeInYears    - Scalar. Foo foo foo foo foo foo foo foo foo foo
%   NDlabel               - String.
%
% Optional key/value pairs:
%  'dropBoxBaseDir'       - Scalar. Bar bar bar bar bar bar bar bar bar bar
%                           bar bar bar bar bar bar bar bar bar bar bar bar
%                           bar bar bar bar bar bar
%  'projectName'          - Scalar. Bar bar bar bar bar bar bar bar bar bar
%                           bar bar bar bar bar bar bar bar bar bar bar bar
%                           bar bar bar bar bar bar
%  'primaryHeadRoom'      - Scalar. Bar bar bar bar bar bar bar bar bar bar
%                           bar bar bar bar bar bar bar bar bar bar bar bar
%                           bar bar bar bar bar bar
%  'primariesToMaximizeSets' - 1x2 cell. We set several primariesToMaximize
%                           so that the L-M modulation tends to find
%                           solutions with large modulation depth. This is
%                           a hand-tweaked solution that we have found
%                           works.
%  'xyTarget'             - 1x2 vector. The background XY chromaticity
%                           we will target. This was found by
%                           trial-and-error search for a background that
%                           provided good, wide field L-M contrast.
%  'searchBackgroundFlag' - Logical. Bar bar bar bar bar bar bar bar bar bar
%                           bar bar bar bar bar bar bar bar bar bar bar bar
%
% Outputs:
%   None. The routine saves modFiles at particular locations in the DropBox
%   hierarchy.
%
% Examples:
%{
    subjectID = 'HERO_gka';
    observerAgeInYears = 55;
    NDlabel = '0x5';
    generateModResultsForDCPT(subjectID,observerAgeInYears,NDlabel);
%}

% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('dropBoxBaseDir',getpref('combiExperiments','dropboxBaseDir'),@ischar);
p.addParameter('projectName','combiLED',@ischar);
p.addParameter('primaryHeadRoom',0.05,@isnumeric);
p.addParameter('primariesToMaximizeSets',{[1:8],[]},@iscell);
p.addParameter('xyTarget',[0.453178;0.348074],@isnumeric);
p.addParameter('searchBackgroundFlag',true,@islogical);
p.parse(varargin{:})

%  Pull out of the p.Results structure
primaryHeadRoom = p.Results.primaryHeadRoom;
primariesToMaximizeSets = p.Results.primariesToMaximizeSets;
xyTarget = p.Results.xyTarget;
searchBackgroundFlag = p.Results.searchBackgroundFlag;

% Define our DropBox subdirectory and cal file subdirectory
dropBoxSubDir = 'FLIC_data';
calSubDir = 'DCPT';

% The diameter of the stimulus field in degrees
fieldSizeDeg = 30;

% Define the calibration files
baseCalOptions = {'CombiLED-C_irFilter-C_cassette-C_ND0_classicEyePiece-C', ...
    'CombiLED-D_irFilter-D_cassette-D_ND0_classicEyePiece-D'};
maxSPDCalOptions = {'CombiLED-C_irFilter-C_cassette-C_ND0_classicEyePiece-C_maxSpectrum', ...
    'CombiLED-D_irFilter-D_cassette-D_ND0_classicEyePiece-D_maxSpectrum'};
targetSPDCalOptions = {['CombiLED-C_irFilter-C_cassette-C_ND' NDlabel '_classicEyePiece-C_maxSpectrum.mat'], ...
    ['CombiLED-D_irFilter-D_cassette-D_ND' NDlabel '_classicEyePiece-D_maxSpectrum.mat']};

% The directions for which we will create modulations
modulationDirections = {'LminusM_wide','LightFlux'};

% The contrastMatchConstraint controls how closely the modResult meets the
% contrast specifications present in the modulation dictionary. We want
% this to be relatively strict for the L–M and L directions.
contrastMatchConstraintSet = [3,1];

% The names of the two combLEDs
combiLEDLabel = {'C', 'D'};

% Loop for combis
for iCombi = 1:2

    % Load the base cal and the max cal file for the ND of interest
    baseCalName = baseCalOptions{iCombi};
    baseCal = loadCalByName(baseCalName, calSubDir);
    maxSPDCalName = maxSPDCalOptions{iCombi};
    maxSPDCal = loadCalByName(maxSPDCalName, calSubDir);
    targetSPDCalName = targetSPDCalOptions{iCombi};
    targetSPDCal = loadCalByName(targetSPDCalName, calSubDir);

    % Obtain the transmittance for this ND filter setting
    transmittance = targetSPDCal.rawData.gammaCurveMeanMeasurements ./ maxSPDCal.rawData.gammaCurveMeanMeasurements;

    % Modify this cal file to account for ND transmittance
    cal = baseCal;
    for ii = 1:size(cal.processedData.P_device,2)
        cal.processedData.P_device(:,ii) = ...
            cal.processedData.P_device(:,ii) .* transmittance;
    end
    cal.processedData.P_ambient = cal.processedData.P_ambient .* ...
        transmittance;

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

    %% Create the L-M direction

    % Create the modulation
    whichDirection = modulationDirections{1};
    modResult = designModulation(whichDirection,photoreceptors,cal,...
        'primaryHeadRoom',primaryHeadRoom,...
        'searchBackground',searchBackgroundFlag,...
        'xyTarget',xyTarget,...
        'backgroundPrimaryHeadroomUb',0.45,...
        'contrastMatchConstraint',contrastMatchConstraintSet(1));
    figHandle = plotModResult(modResult);
    drawnow

    % Define the data directory
    modDir = fullfile(...
        p.Results.dropBoxBaseDir,...
        dropBoxSubDir,...,
        p.Results.projectName,...
        subjectID,[whichDirection '_ND' NDlabel '_shifted']);

    % Create the modDir for the subject
    if ~isfolder(modDir)
        mkdir(modDir)
    end

    % Save the mod result and figure
    filename = fullfile(modDir,['modResult_' combiLEDLabel{iCombi} '.mat']);
    save(filename,'modResult');
    filename = fullfile(modDir,['modResult_' combiLEDLabel{iCombi} '.pdf']);
    saveas(figHandle,filename,'pdf')
    close(figHandle)

    % Extract the background settings
    settingsBackground = modResult.settingsBackground;

    %% LightFlux
    whichDirection = modulationDirections{2};
    modResult = designModulation(whichDirection,photoreceptors,cal,...
        'primaryHeadRoom',primaryHeadRoom,...
        'searchBackground',false,...
        'backgroundPrimary',settingsBackground,...
        'contrastMatchConstraint',contrastMatchConstraintSet(2));
    figHandle = plotModResult(modResult);
    drawnow

    % Define the data directory
    modDir = fullfile(...
        p.Results.dropBoxBaseDir,...
        dropBoxSubDir,...,
        p.Results.projectName,...
        subjectID,[whichDirection '_ND' NDlabel '_shifted']);

    % Create the modDir for the subject
    if ~isfolder(modDir)
        mkdir(modDir)
    end

    % Save the mod result and figure
    filename = fullfile(modDir,['modResult_' combiLEDLabel{iCombi} '.mat']);
    save(filename,'modResult');
    filename = fullfile(modDir,['modResult_' combiLEDLabel{iCombi} '.pdf']);
    saveas(figHandle,filename,'pdf')
    close(figHandle)

end
end


