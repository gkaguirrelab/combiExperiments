function runPuffLightModulate(subjectID,varargin)
% Psychometric measurement of discrmination threshold for simultaneous air
% puffs of varying intensity. It takes about 14 seconds per trial. With 3
% waveforms to test, and 10 trials per object, a single block takes 7
% minutes. Four blocks can be completed in half an hour.
%
% Examples:
%{
    subjectID = 'HERO_gka';
    runPuffLightModulate(subjectID,'simulateModeFlag',false);
%}

% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('dropBoxBaseDir',getpref('combiExperiments','dropboxBaseDir'),@ischar);
p.addParameter('dropBoxSubDir','BLNK_data',@ischar);
p.addParameter('projectName','PuffLight',@ischar);
p.addParameter('directions',{'Mel','LMS','S_peripheral'},@iscell);
p.addParameter('phases',[0,pi],@isnumeric);
p.addParameter('nTrialsPerObj',1,@isnumeric);
p.addParameter('nBlocks',4,@isnumeric);
p.addParameter('adaptDurationMins',5,@isnumeric);
p.addParameter('simulateModeFlag',false,@islogical);
p.addParameter('verboseLightObj',false,@islogical);
p.addParameter('verboseCameraObj',false,@islogical);
p.addParameter('verbosePsychObj',true,@islogical);
p.parse(varargin{:})

% Pull variables out of the p.Results structure
nTrialsPerObj = p.Results.nTrialsPerObj;
nBlocks = p.Results.nBlocks;
directions = p.Results.directions;
phases = p.Results.phases;
adaptDurationMins = p.Results.adaptDurationMins;
simulateModeFlag = p.Results.simulateModeFlag;
verboseLightObj = p.Results.verboseLightObj;
verboseCameraObj = p.Results.verboseCameraObj;
verbosePsychObj = p.Results.verbosePsychObj;

% The number of modulation directions and phases we will study
nDirections = length(directions);
nPhases = length(phases);

% Set our experimentName
experimentName = 'modulate';

% Set a random seed
rng('shuffle');

% Define the modulation and data directories
dataDir = fullfile(...
    p.Results.dropBoxBaseDir,...
    p.Results.dropBoxSubDir,...,
    p.Results.projectName,...
    experimentName,...
    subjectID);

% Load one of the modResults to get a gamma table
modResultFile = fullfile(dataDir,['modResult_' directions{1} '.mat']);
load(modResultFile,'modResult');

% Set up the devices
if ~simulateModeFlag

    % Set up the AirPuff IR camera recording
    videoDataPath = fullfile(experimentName,subjectID);
    irCameraObj = PuffCameraControl(videoDataPath);

    % Set up the CombiLED LightObj
    LightObj = CombiLEDcontrol('verbose',verboseLightObj);

    % Set the gamma table
    LightObj.setGamma(modResult.meta.cal.processedData.gammaTable);

else
    irCameraObj = [];
    LightObj = [];
end

% Provide instructions
fprintf('**********************************\n');
fprintf('**********************************\n\n');

% Create a directory for the subject
if ~isfolder(dataDir)
    mkdir(dataDir)
end

% Assemble the psychObj array, looping over the different modulation
% directions we will study
psychObjArray = {};

% Loop over light pulse waveforms
for dd = 1:nDirections

    % Get this direction
    whichDirection = directions{dd};

    % Loop over the phases
    for pp = 1:nPhases

        % Define the filestem for this psychometric object
        psychFileStem = sprintf( [subjectID '_' experimentName ...
            'direction-' whichDirection '_phase-%2.2f'], phases(pp) );

        % Create or load the psychometric object
        filename = fullfile(dataDir,[psychFileStem '.mat']);
        if isfile(filename)
            % Load the object
            load(filename,'psychObj');
            % Put in fresh control objects
            psychObj.irCameraObj = irCameraObj;
            psychObj.LightObj = LightObj;
        else
            % Load this modResult
            modResultFile = fullfile(dataDir,['modResult_' whichDirection '.mat']);
            load(modResultFile,'modResult');
            % Create the object
            psychObj = PsychPuffLightModulate(irCameraObj,LightObj,modResult,...
                'trialLabel',psychFileStem,...
                'lightModPhase',phases(pp),...
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

% How many psychObjs do we have
nPsychObjs = length(psychObjArray);


%% Adapt
% Grab the first psychObj; we will assign the adaptation period to this
psychObj = psychObjArray{1};

% Initialize the display
psychObj.initializeDisplay;

% refresh the irObj
if ~simulateModeFlag
    irCameraObj = PuffCameraControl(videoDataPath,'verbose',verboseCameraObj);
    psychObj.irCameraObj = irCameraObj;
end

% Wait for the subject to start adaptation
Speak('adapt');
fprintf('Press enter to start adaptation...');
input('');

% Start the light ramp
if ~simulateModeFlag

    % Count down the minutes and record a video during each minute
    for mm = 1:adaptDurationMins
        % Define the label to be used for the adaptation video recording
        recordLabel = sprintf( [subjectID '_' experimentName ...
            '_direction-' whichDirection '_adapt-%d' ],mm);
        Speak(sprintf('%d',adaptDurationMins-(mm-1)));
        psychObj.recordAdaptPeriod(recordLabel,55);
        pause(5);
    end
end


%% Loop over blocks
for bb=1:nBlocks

    % Start the block
    Speak('Ready');
    fprintf('Press enter to start block %d...',bb);
    input('');

    % Define a random ordering of the psychObjs
    objIdxList = repmat(1:nPsychObjs,1,nTrialsPerObj);
    [~,tmp]=sort(rand(1,length(objIdxList)));
    objIdxList = objIdxList(tmp);

    % Get an updated irCameraObj
    if ~simulateModeFlag
        irCameraObj = PuffCameraControl(videoDataPath,'verbose',verboseCameraObj);
    end

    % Loop over trials in this run
    for tt = 1:length(objIdxList)

        % Update the camera and light obj object
        if ~simulateModeFlag
            psychObjArray{objIdxList(tt)}.irCameraObj = irCameraObj;
            psychObjArray{objIdxList(tt)}.LightObj = LightObj;
        end

        Speak(sprintf('%d',tt));

        % Present the next trial
        psychObjArray{objIdxList(tt)}.presentTrial;

    end

    % Report completion of this block
    fprintf('done.\n');

    % Store the psychObjArray entries
    for ss = 1:nPsychObjs
        % Grab the next psychObj
        psychObj = psychObjArray{ss};
        % empty the AirPuffObj and LightObj handles and save the psychObj
        psychObj.irCameraObj = [];
        psychObj.LightObj = [];
        save(psychObj.filename,'psychObj');
    end

end % block loop

% Clean up
if ~simulateModeFlag

    clear irCameraObj

    LightObj.goDark;
    LightObj.serialClose;
    clear LightObj
end

end % function
