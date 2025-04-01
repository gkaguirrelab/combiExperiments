function generateModResultsForDCPT(subjectID,observerAgeInYears,NDlabel,varargin)
% We pre-generate the modResult files that define the L–M and LightFlux
% modulations for each subject for the dichoptic rig exoeriments
%
% Examples:
%{
    subjectID = 'HERO_gka';
    observerAgeInYears = 55;
    NDlabel = '1';
    generateModResultsForDCPT(subjectID,observerAgeInYears,NDlabel);
%}

% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('dropBoxBaseDir',getpref('combiExperiments','dropboxBaseDir'),@ischar);
p.addParameter('projectName','combiLED',@ischar);
p.addParameter('primaryHeadRoom',0.10,@isnumeric); % Leave some space for nulling
p.parse(varargin{:})

%  Pull out of the p.Results structure
primaryHeadRoom = p.Results.primaryHeadRoom;

% Define our DropBox subdirectory
dropBoxSubDir = 'FLIC_data';

% The background XY chromaticity we will target. Not currently used. We may
% return to matching the background if we find that the half-on differs a
% bit between the two CombiLEDs
xyTarget = [0.453178;0.348074];

% The diameter of the stimulus field in degrees
fieldSizeDeg = 30;

% Define the calibration files
baseCalOptions = {'CombiLED-C_shortLLG-C_classicEyePiece-C_cassette-C_ND0', ...
    'CombiLED-D_shortLLG-D_classicEyePiece-D_cassette-D_ND0'};
maxSPDCalOptions = {'CombiLED-C_shortLLG-C_classicEyePiece-C_cassette-C_ND0_maxSpectrum', ...
    'CombiLED-D_shortLLG-D_classicEyePiece-D_cassette-D_ND0_maxSpectrum'};
targetSPDCalOptions = {['CombiLED-C_shortLLG-C_classicEyePiece-C_cassette-C_ND' NDlabel '_maxSpectrum.mat'], ...
    ['CombiLED-D_shortLLG-D_classicEyePiece-D_cassette-D_ND' NDlabel '_maxSpectrum.mat']};

% The directions for which we will create modulations
modulationDirections = {'LminusM_wide','L_wide','LightFlux'};

% We set several primariesToMaximize so that the L-M modulation tends to
% find solutions with large modulation depth. This is a hand-tweaked
% solution that we have found works.
primariesToMaximizeSets = {[2 3 6 7],[],[]};

% The contrastMatchConstraint controls how closely the modResult meets the
% contrast specifications present in the modulation dictionary. We want
% this to be relatively strict for the L–M and L directions.
contrastMatchConstraintSet = [3.5,3.5,1];

% The names of the two combLEDs
combiLEDLabel = {'C', 'D'};

% Loop for combis
for iCombi = 1:2

    % Load the base cal and the max cal file for the ND of interest
    baseCalName = baseCalOptions{iCombi};
    baseCal = loadCalByName(baseCalName);
    maxSPDCalName = maxSPDCalOptions{iCombi};
    maxSPDCal = loadCalByName(maxSPDCalName);
    targetSPDCalName = targetSPDCalOptions{iCombi};
    targetSPDCal = loadCalByName(targetSPDCalName);

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

    % Loop over the modulation directions
    for dd = 1:length(modulationDirections)

        % Create the modulation
        whichDirection = modulationDirections{dd};
        modResult = designModulation(whichDirection,photoreceptors,cal,...
            'primaryHeadRoom',primaryHeadRoom,'searchBackground',false,...
            'primariesToMaximize',primariesToMaximizeSets{dd},...
            'contrastMatchConstraint',contrastMatchConstraintSet(dd));
        figHandle = plotModResult(modResult);
        drawnow

        % Define the data directory
        modDir = fullfile(...
            p.Results.dropBoxBaseDir,...
            dropBoxSubDir,...,
            p.Results.projectName,...
            subjectID,[whichDirection '_ND' NDlabel]);

        % Create the modDir for the subject
        if ~isfolder(modDir)
            mkdir(modDir)
        end

        % Save the mod result and plot
        filename = fullfile(modDir,['modResult_' combiLEDLabel{iCombi} '.mat']);
        save(filename,'modResult');
        filename = fullfile(modDir,['modResult_' combiLEDLabel{iCombi} '.pdf']);
        saveas(figHandle,filename,'pdf')
        close(figHandle)

    end
end
end


