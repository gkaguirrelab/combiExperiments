function runDiscrimPuffThresh(subjectID,whichDirection,varargin)
% Psychometric measurement of discrmination threshold for simultaneous air
% puffs of varying intensity.
%
% Examples:
%{
    subjectID = 'HERO_gka';
    whichDirection = 'LightFlux';
    refPuffSetPSI = 5;
    runDiscrimPuffThresh(subjectID,whichDirection,'refPuffSetPSI',refPuffSetPSI);
%}

% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('dropBoxBaseDir',getpref('combiExperiments','dropboxBaseDir'),@ischar);
p.addParameter('dropBoxSubDir','BLNK_data',@ischar);
p.addParameter('projectName','PuffLight',@ischar);
p.addParameter('refPuffSetPSI',logspace(log10(2),log10(20),5),@isnumeric);
p.addParameter('lightPulseContrastLevels',[0 0.5],@isnumeric);
p.addParameter('nTrialsPerObj',5,@isnumeric);
p.addParameter('nBlocks',1,@isnumeric);
p.addParameter('simulateModeFlag',false,@islogical);
p.addParameter('verbosePuffObj',false,@islogical);
p.addParameter('verboseLightObj',false,@islogical);
p.addParameter('verbosePsychObj',true,@islogical);
p.parse(varargin{:})

%  Pull out of the p.Results structure
nTrialsPerObj = p.Results.nTrialsPerObj;
nBlocks = p.Results.nBlocks;
refPuffSetPSI = p.Results.refPuffSetPSI;
lightPulseContrastLevels = p.Results.lightPulseContrastLevels;
simulateModeFlag = p.Results.simulateModeFlag;
verbosePuffObj = p.Results.verbosePuffObj;
verboseLightObj = p.Results.verboseLightObj;
verbosePsychObj = p.Results.verbosePsychObj;

% The number of stimulus intensity levels
nLevels = length(refPuffSetPSI);

% The number of light pulse contrast levels
nContrasts = lightPulseContrastLevels;

% Set our experimentName
experimentName = 'DSCM';

% Set the labels for the high and low stimulus ranges
stimParamLabels = {'hi','low'};

% Calculate the total number of trials per block
nTrialsPerBlock = nTrialsPerObj * nLevels * nContrasts * length(stimParamLabels);

% Set a random seed
rng('shuffle');

% Define the modulation and data directories
dataDir = fullfile(...
    p.Results.dropBoxBaseDir,...
    p.Results.dropBoxSubDir,...,
    p.Results.projectName,...
    experimentName,...
    subjectID);

% Load the modResult
modResultFile = fullfile(dataDir,['modResult_' whichDirection '.mat']);
load(modResultFile,'modResult');

% Set up the devices
if ~simulateModeFlag

    % Set up the AirPuffObj
    AirPuffObj = PuffControl('verbose',verbosePuffObj);

    % Set up the AirPuff IR camera recording
    rpiDataPath = fullfile(experimentName,subjectID);
    irCameraObj = PuffCameraControl(rpiDataPath);

    % Set up the CombiLED LightObj
    LightObj = CombiLEDcontrol('verbose',verboseLightObj);

    % Set the gamma table
    LightObj.setGamma(modResult.meta.cal.processedData.gammaTable);
else
    AirPuffObj = [];
    LightObj = [];
end

% Provide instructions
fprintf('**********************************\n');
fprintf('On each of many trials you will be presented with air puffs in two\n');
fprintf('intervals. Your job is to indicate which interval was stronger by pressing the\n');
fprintf('1 or 2 key on the numeric key pad. Each block has %d trials after\n',nTrialsPerBlock);
fprintf('which you may take a brief break. There are a total of %d blocks.\n',nBlocks);
fprintf('**********************************\n\n');

% Create a directory for the subject
if ~isfolder(dataDir)
    mkdir(dataDir)
end

% Assemble the psychObj array, randomzing over the set of reference
% puff intensities, and looping over the high and low range of
% the discrimination function
psychObjArray = {};

for nn = 1:nLevels

    % Get this reference intensity
    refPuffPSI = refPuffSetPSI(nn);

    % Define the puff duration, which is 1/refPuffPSI in seconds
    puffDurSecs = 1/refPuffPSI;

    % Loop over contrast levels of the light pulse
    for cc = 1:length(lightPulseContrastLevels)

        % Get this pulse contrast
        lightPulseContrast = lightPulseContrastLevels(cc);

        % Loop over high and low sides of the puff reference range
        for ss = 1:length(stimParamLabels)

            % Define this stimParamSide
            stimParamSide = stimParamLabels{ss};

            % Define the filestem for this psychometric object
            psychFileStem = sprintf( [subjectID '_' experimentName ...
                'direction-' whichDirection ...
                '_refPSI-%2.2f_pulseContrast-%2.2f_' stimParamLabels{ss}],...
                refPuffPSI,lightPulseContrast);

            % Create or load the psychometric object
            filename = fullfile(dataDir,[psychFileStem '.mat']);
            if isfile(filename)
                % Load the object
                load(filename,'psychObj');
                % Put in the fresh AirPuffObj
                psychObj.AirPuffObj = AirPuffObj;
                % Put in the fresh CombiLED
                psychObj.LightObj = LightObj;
                % Initiate the CombiAir settings
                psychObj.initializeDisplay;
                % Increment blockIdx
                psychObj.blockIdx = psychObj.blockIdx+1;
                psychObj.blockStartTimes(psychObj.blockIdx) = datetime();
            else
                % Create the object
                psychObj = PsychDiscrimPuffThreshold(AirPuffObj,LightObj,refPuffPSI,modResult,...
                    'stimParamSide',stimParamSide,...
                    'lightPulseContrast',lightPulseContrast,...
                    'puffDurSecs',puffDurSecs,...
                    'simulateStimuli',simulateModeFlag,'simulateResponse',simulateModeFlag,...
                    'verbose',verbosePsychObj);
                % Store the filename
                psychObj.filename = filename;
            end

            % Store in the psychObjArray
            psychObjArray{end+1} = psychObj;

            % Clear the psychObj
            clear psychObj

        end
    end
end

nPsychObjs = length(psychObjArray);

% Prepare to loop over blocks
for bb=1:nBlocks

    % Start the block
    Speak('Ready');
    fprintf('Press enter to start block %d...',bb);
    input('');

    % Store the block start time
    for ss = 1:nPsychObjs
        blockStartTime = datetime();
        psychObjArray{ss}.blockStartTimes(psychObjArray{ss}.blockIdx) = blockStartTime;
    end

    % Present the trials in a random order
    for ii = 1:nTrialsPerObj
        % Create a random ordering of the psych objects
        [~,psychObjIdx] = sort(rand(1,nPsychObjs));
        for tt = 1:nPsychObjs
            psychObjArray{psychObjIdx(tt)}.presentTrial
        end
    end

    % Report completion of this block
    fprintf('done.\n');

    % Store the psychObjArray entries
    for ss = 1:nPsychObjs
        % Grab the next psychObj
        psychObj = psychObjArray{ss};
        % empty the AirPuffObj and LightObj handles and save the psychObj
        psychObj.AirPuffObj = [];
        psychObj.LightObj = [];
        save(psychObj.filename,'psychObj');
    end

end % block loop

% Clean up
if ~simulateModeFlag
    AirPuffObj.serialClose;
    clear AirPuffObj

    LightObj.goDark;
    LightObj.serialClose;
    clear LightObj
end

end % function
