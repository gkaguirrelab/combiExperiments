function generateModResulstForDMTF(subjectID,varargin)
% Psychometric measurement of accuracy and bias in reproduction of the
% frequency of a flickering stimulus after a delay. The code manages a
% series of files that store the data from the experiment. As configured,
% each testing "session" has 20 trials and is about 4 minutes in duration.
%
% Examples:
%{
    subjectID = 'DEMO_001';
    modDirection = 'LightFlux';
    testContrast = 0.8;
    load(fullfile(getpref('combiLEDToolbox','CalDataFolder'),'CombiLED-B_shortLLG_irFilter_classicEyePiece_ND0.mat'),'cals');
    cal = cals{end};
    runDelayedMatchExperiment(subjectID,modDirection,testContrast,'cal',cal);
%}

% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('dropBoxBaseDir',getpref('combiExperiments','dropboxBaseDir'),@ischar);
p.addParameter('projectName','combiLED',@ischar);
p.addParameter('observerAgeInYears',25,@isnumeric);
p.addParameter('pupilDiameterMm',3,@isnumeric);
p.addParameter('primaryHeadRoom',0.1,@isnumeric);
p.parse(varargin{:})

%  Pull out of the p.Results structure
observerAgeInYears = p.Results.observerAgeInYears;
pupilDiameterMm = p.Results.pupilDiameterMm;
primaryHeadRoom = p.Results.primaryHeadRoom;

% Set our experimentName
experimentName = 'DMTF';

% Set a random seed
rng('shuffle');

% The directions and ND settings we will use
NDlabels = {'0x5','3x5'};
directions = {'LminusM_wide','LightFlux_reduced'};

% The background XY chromaticity we will target
xyTarget = [0.453178;0.348074];

% Define and load the observer photoreceptors
photoreceptors = photoreceptorDictionaryHuman('observerAgeInYears',observerAgeInYears,'pupilDiameterMm',pupilDiameterMm);

% Load the base cal and the max (ND0) cal
baseCalName = 'CombiLED-B_shortLLG_classicEyePiece_irFilter_Cassette-ND0';
baseCal = loadCalByName(baseCalName);
maxSPDCalName = 'CombiLED-B_shortLLG_classicEyePiece_irFilter_Cassette-ND0_maxSpectrum';
maxSPDCal = loadCalByName(maxSPDCalName);

% Loop over the experiment sets
for nn = 1:length(NDlabels)

    % Obtain the transmittance for this ND filter setting
    targetSPDCalName = ['CombiLED-B_shortLLG_classicEyePiece_irFilter_Cassette-ND' NDlabels{nn} '_maxSpectrum'];
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

    % Loop over directions
    for dd = 1:length(directions)

        % Get this direction and create the mod result differently for L-M
        % and light flux
        whichDirection = directions{dd};

        if dd==1
            modResultAll{nn,1} = designModulation(whichDirection,photoreceptors,cal,...
                'primaryHeadRoom',primaryHeadRoom,'contrastMatchConstraint',3,...
                'xyTarget',xyTarget,'searchBackground',true);
        else
            backgroundPrimary = modResultAll{nn,1}.settingsBackground;
            modResultAll{nn,2} = designModulation(whichDirection,photoreceptors,cal,...
                'primaryHeadRoom',primaryHeadRoom,'contrastMatchConstraint',3,...
                'backgroundPrimary',backgroundPrimary,'searchBackground',true,...
                'xyTol',0,'xyTolWeight',1e3);
        end

        % Define the modulation and data directories
        modDir = fullfile(...
            p.Results.dropBoxBaseDir,...
            'FLIC_data',...,
            p.Results.projectName,...
            subjectID,[whichDirection '_ND' NDlabels{nn}]);
        dataDir = fullfile(modDir,experimentName);

        % Create a directory for the subject
        if ~isfolder(dataDir)
            mkdir(dataDir)
        end

        % Save the mod result and plot
        filename = fullfile(modDir,'modResult.mat');

        modResult = modResultAll{nn,dd};
        save(filename,'modResult');
        figHandle = plotModResult(modResult,'off');
        filename = fullfile(modDir,'modResult.pdf');
        saveas(figHandle,filename,'pdf')
        close(figHandle)

    end % Loop over directions
end % Loop over ND filters

end % primary function