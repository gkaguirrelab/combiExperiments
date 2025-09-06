function runPuffLightPSE(subjectID,whichDirection,varargin)
% Psychometric measurement of discrmination threshold for simultaneous air
% puffs of varying intensity. It takes about 14 seconds per trial. With 3
% waveforms to test, and 10 trials per object, a single block takes 7
% minutes. Four blocks can be completed in half an hour.
%
% Examples:
%{
    subjectID = 'HERO_gka';
    whichDirection = 'LightFlux';
    runPuffLightPSE(subjectID,whichDirection);
%}

% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('dropBoxBaseDir',getpref('combiExperiments','dropboxBaseDir'),@ischar);
p.addParameter('dropBoxSubDir','BLNK_data',@ischar);
p.addParameter('projectName','PuffLight',@ischar);
p.addParameter('refPuffPSI',15,@isnumeric);
p.addParameter('puffDurSecs',0.075,@isnumeric);
p.addParameter('lightPulseModContrast',1.0,@isnumeric);
p.addParameter('lightPulseWaveforms',{'high-low','low-high','background'},@iscell);
p.addParameter('nTrialsPerObj',10,@isnumeric);
p.addParameter('nBlocks',4,@isnumeric);
p.addParameter('simulateModeFlag',false,@islogical);
p.addParameter('verbosePuffObj',false,@islogical);
p.addParameter('verboseLightObj',false,@islogical);
p.addParameter('verboseCameraObj',false,@islogical);
p.addParameter('verbosePsychObj',true,@islogical);
p.parse(varargin{:})

% Pull variables out of the p.Results structure
nTrialsPerObj = p.Results.nTrialsPerObj;
nBlocks = p.Results.nBlocks;
refPuffPSI = p.Results.refPuffPSI;
puffDurSecs = p.Results.puffDurSecs;
lightPulseModContrast = p.Results.lightPulseModContrast;
lightPulseWaveforms = p.Results.lightPulseWaveforms;
simulateModeFlag = p.Results.simulateModeFlag;
verbosePuffObj = p.Results.verbosePuffObj;
verboseLightObj = p.Results.verboseLightObj;
verboseCameraObj = p.Results.verboseCameraObj;
verbosePsychObj = p.Results.verbosePsychObj;

% The number of light pulse contrast levels
nWaveforms = length(lightPulseWaveforms);

% Set our experimentName
experimentName = 'puffPSE';

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
    videoDataPath = fullfile(experimentName,subjectID);
    irCameraObj = PuffCameraControl(videoDataPath);

    % Set up the CombiLED LightObj
    LightObj = CombiLEDcontrol('verbose',verboseLightObj);

    % Set the gamma table
    LightObj.setGamma(modResult.meta.cal.processedData.gammaTable);
else
    AirPuffObj = [];
    irCameraObj = [];
    LightObj = [];
end

% Provide instructions
fprintf('**********************************\n');
fprintf('On each of many trials you will be presented with air puffs in two\n');
fprintf('intervals. Your job is to indicate which interval was stronger by pressing the\n');
fprintf('1 or 2 key on the numeric key pad. Each block has %d trials after\n',nTrialsPerObj);
fprintf('which you may take a brief break. There are a total of %d blocks.\n',nBlocks);
fprintf('**********************************\n\n');

% Create a directory for the subject
if ~isfolder(dataDir)
    mkdir(dataDir)
end

% Assemble the psychObj array, looping over the different light pulse
% waveforms we will study
psychObjArray = {};

% Loop over light pulse waveforms
for ww = 1:nWaveforms

    % Get this waveform
    lightPulseWaveform = lightPulseWaveforms{ww};

    % Define the filestem for this psychometric object
    psychFileStem = sprintf( [subjectID '_' experimentName ...
        'direction-' whichDirection ...
        '_refPSI-%2.2f_pulseContrast-%2.2f_' lightPulseWaveform ],...
        refPuffPSI,lightPulseModContrast);

    % Create or load the psychometric object
    filename = fullfile(dataDir,[psychFileStem '.mat']);
    if isfile(filename)
        % Load the object
        load(filename,'psychObj');
        % Put in fresh control objects
        psychObj.AirPuffObj = AirPuffObj;
        psychObj.irCameraObj = irCameraObj;
        psychObj.LightObj = LightObj;
        % Initiate the CombiAir settings
        psychObj.initializeDisplay;
        % Increment blockIdx
        psychObj.blockIdx = psychObj.blockIdx+1;
        psychObj.blockStartTimes(psychObj.blockIdx) = datetime();
    else
        % Create the object
        psychObj = PsychPuffLightPSE(...
            AirPuffObj,irCameraObj,LightObj,refPuffPSI,modResult,...
            'trialLabel',psychFileStem,...
            'lightPulseWaveform',lightPulseWaveform,...
            'lightPulseModContrast',lightPulseModContrast,...
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

% This should be equal to the number of waveforms
nPsychObjs = length(psychObjArray);

% Prepare to loop over blocks
for bb=1:nBlocks

    % Refresh the connections on the objects
    if ~simulateModeFlag
        AirPuffObj.serialClose;
        AirPuffObj = PuffControl('verbose',verbosePuffObj);
        irCameraObj = PuffCameraControl(videoDataPath,'verbose',verboseCameraObj);
    end

    % Start the block
    Speak('Ready');
    fprintf('Press enter to start block %d...',bb);
    input('');

    % Store the block start time and refresh the device objects
    for ss = 1:nPsychObjs
        blockStartTime = datetime();
        psychObjArray{ss}.blockStartTimes(psychObjArray{ss}.blockIdx) = blockStartTime;
        psychObjArray{ss}.AirPuffObj = AirPuffObj;
        psychObjArray{ss}.irCameraObj = irCameraObj;
        psychObjArray{ss}.LightObj = LightObj;
    end

    % Present the trials in a random order
    for ii = 1:nTrialsPerObj
        % Create a random ordering of the psych objects
        [~,psychObjIdx] = sort(rand(1,nPsychObjs));
        % Loop over this random ordering
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
        psychObj.irCameraObj = [];
        psychObj.LightObj = [];
        save(psychObj.filename,'psychObj');
    end

end % block loop

% Clean up
if ~simulateModeFlag
    AirPuffObj.serialClose;
    clear AirPuffObj

    clear irCameraObj

    LightObj.goDark;
    LightObj.serialClose;
    clear LightObj
end

end % function
