function generateModResulstForDMTF(subjectID,observerAgeInYears,NDlabel,varargin)
% We pre-generate the modResult files that define the L–M and LightFlux
% modulations for each subject
%
% We defiine a vector of primary head-room values that gives us extra
% caution with the poorly behaved, 7th primary of the CombiLED-B device.
% Examples:
%{
    subjectID = 'HERO_gka';
    observerAgeInYears = 54;
    NDlabel = '0x5';
    generateModResulstForDMTF(subjectID,observerAgeInYears,NDlabel);
%}

% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('dropBoxBaseDir',getpref('combiExperiments','dropboxBaseDir'),@ischar);
p.addParameter('projectName','combiLED',@ischar);
p.addParameter('primaryHeadRoom',[0.075,0.075,0.075,0.075,0.075,0.075,0.20,0.075],@isnumeric);
p.parse(varargin{:})

%  Pull out of the p.Results structure
primaryHeadRoom = p.Results.primaryHeadRoom;

% Set our experimentName
experimentName = 'DUAL';

% Define our DropBox subdirectory
dropBoxSubDir = 'FLIC_data';

% The background XY chromaticity we will target
xyTarget = [0.453178;0.348074];

% The diameter of the stimulus field in degrees
fieldSizeDeg = 30;

baseCalOptions = {'CombiLED-A_shortLLG-A_cassette-A_classicEyePiece-A_ND0', ...
    'CombiLED-B_shortLLG-B_cassette-B_classicEyePiece-B_ND0'};

maxSPDCalOptions = {'CombiLED-B_shortLLG_classicEyePiece_irFilter_Cassette-ND0_maxSpectrum',...
   'CombiLED-B_shortLLG_classicEyePiece_irFilter_Cassette-ND0_maxSpectrum'};

label = {'A', 'B'};

for iCombi = 1:2
    % Load the base cal and the max (ND0) cal
    baseCalName = baseCalOptions{iCombi};
    baseCal = loadCalByName(baseCalName);
    maxSPDCalName = maxSPDCalOptions{iCombi};
    maxSPDCal = loadCalByName(maxSPDCalName);

    % Obtain the transmittance for this ND filter setting
    % Change label{2} to label{iCombi} once we have two max spectrum files
    targetSPDCalName = ['CombiLED-' label{2} '_shortLLG_classicEyePiece_irFilter_Cassette-ND' NDlabel '_maxSpectrum'];
    targetSPDCal = loadCalByName(targetSPDCalName);
    transmittance = targetSPDCal.rawData.gammaCurveMeanMeasurements ./ maxSPDCal.rawData.gammaCurveMeanMeasurements;

    % Create this cal file
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

    %% Create the L-M modulation
    whichDirection = 'LminusM_wide';

    modResult = designModulation(whichDirection,photoreceptors,cal,...
        'primaryHeadRoom',primaryHeadRoom,'contrastMatchConstraint',3,...
        'xyTarget',xyTarget,'searchBackground',true);
    figHandle = plotModResult(modResult);
    drawnow

    % Define the data directories
    modDir = fullfile(...
        p.Results.dropBoxBaseDir,...
        dropBoxSubDir,...,
        p.Results.projectName,...
        subjectID,[whichDirection '_ND' NDlabel]);
    dataDir = fullfile(modDir,experimentName);

    % Create a directory for the subject
    if ~isfolder(dataDir)
        mkdir(dataDir)
    end

    % Save the mod result and plot
    filename = fullfile(modDir, ['modResult' label{iCombi} '.mat']);
    save(filename,'modResult');
    filename = fullfile(modDir,['modResult' label{iCombi} '.pdf']);
    saveas(figHandle,filename,'pdf')
    close(figHandle)

    % Save the background settings for the L-M modulation
    backgroundPrimary = modResult.settingsBackground;


    %% Create the LightFlux modulation
    whichDirection = 'LightFlux';

    modResult = designModulation(whichDirection,photoreceptors,cal,...
        'primaryHeadRoom',primaryHeadRoom,'backgroundPrimary',backgroundPrimary);
    figHandle = plotModResult(modResult);
    drawnow

    % Define the data directories
    modDir = fullfile(...
        p.Results.dropBoxBaseDir,...
        dropBoxSubDir,...,
        p.Results.projectName,...
        subjectID,[whichDirection '_ND' NDlabel]);
    dataDir = fullfile(modDir,experimentName);

    % Create a directory for the subject
    if ~isfolder(dataDir)
        mkdir(dataDir)
    end

    % Save the mod result and plot
    filename = fullfile(modDir,['modResult' label{iCombi} '.mat']);
    save(filename,'modResult');
    filename = fullfile(modDir,['modResult' label{iCombi} '.pdf']);
    saveas(figHandle,filename,'pdf')
    close(figHandle)

end


end