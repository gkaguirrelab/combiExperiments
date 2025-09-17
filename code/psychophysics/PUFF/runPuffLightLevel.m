function runPuffLightLevel(subjectID,varargin)
% Observers attempt to detect an infrequent, brief darkening of the
% stimulus field against different overall light levels. Video recording of
% the eye is obtained during this time. The purpose is to determine if
% blink rate differs with different light background levels.
%
% Examples:
%{
    subjectID = 'HERO_gka';
    whichSequence = 1;
    runPuffLightModulate(subjectID,'simulateModeFlag',false);
%}

% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('dropBoxBaseDir',getpref('combiExperiments','dropboxBaseDir'),@ischar);
p.addParameter('dropBoxSubDir','BLNK_data',@ischar);
p.addParameter('projectName','PuffLight',@ischar);
p.addParameter('direction','LightFlux',@iscell);
p.addParameter('contrastLevels',[0.0625,0.1250,0.25,0.5,1.0],@isnumeric);
p.addParameter('whichSequence',1,@isnumeric);
p.addParameter('simulateModeFlag',false,@islogical);
p.addParameter('verboseLightObj',false,@islogical);
p.addParameter('verboseCameraObj',false,@islogical);
p.addParameter('verbosePsychObj',true,@islogical);
p.parse(varargin{:})

% Pull variables out of the p.Results structure
direction = p.Results.direction;
contrastLevels = p.Results.contrastLevels;
whichSequence = p.Results.whichSequence;
simulateModeFlag = p.Results.simulateModeFlag;
verboseLightObj = p.Results.verboseLightObj;
verboseCameraObj = p.Results.verboseCameraObj;
verbosePsychObj = p.Results.verbosePsychObj;

% Hard-code a couple of deBruijn sequences we will use to define the
% stimulus order across blocks. In all cases, the sequence begins with the
% middle intensity stimulus. The first trial is repeated, allowing us to
% discard the first trial and have a fully counter-balanced sequence.
sequenceSet{1} = [3,3,1,4,5,5,4,1,2,3,2,2,1,5,3,4,4,3,5,2,4,2,5,1,1,3];
sequenceSet{2} = [3,3,2,5,3,5,2,4,3,4,1,1,5,1,3,1,2,2,1,4,4,5,5,4,2,3];
sequenceSet{3} = [3,3,4,2,5,3,2,4,5,1,4,1,1,5,4,4,3,5,5,2,1,2,2,3,1,3];
sequenceSet{4} = [3,3,1,4,5,1,2,2,3,2,1,3,4,2,4,4,3,5,2,5,5,4,1,1,5,3];

% The number of of contrast levels
nLevels = length(contrastLevels);

% Set our experimentName
experimentName = 'lightLevel';

% Set a random seed
rng('shuffle');

% Define the modulation and data directories
dataDir = fullfile(...
    p.Results.dropBoxBaseDir,...
    p.Results.dropBoxSubDir,...,
    p.Results.projectName,...
    experimentName,...
    subjectID);

% Load the mod result
modResultFile = fullfile(dataDir,['modResult_' direction '.mat']);
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
fprintf('Your job is to watch for a sudden, brief darkening of the light.\n');
fprintf('When you hear "ready" press return to start the test. Each test\n');
fprintf('lasts 30 seconds. You will hear a beep, and then the light in the\n');
fprintf('sphere will become brighter. Keep your eyes open and look straight\n');
fprintf('ahead into the center of the circles you see directly in front of\n');
fprintf('your eyes. The light may be uncomfortably bright. You may blink,\n');
fprintf('but do your best to keep your eyes open and look straight ahead.\n');
fprintf('When you see a sudden, split-second darkening of the light, press\n');
fprintf('the space bar. You will hear a beep if you were correct, and a\n');
fprintf('buzz if you missed it.\n');
fprintf('After the test is over, the spheres will go dark again. When\n');
fprintf('you are ready, press return to start the next test. A given\n');
fprintf('you are ready, press return to start the next test. A session\n');
fprintf('has 26 tests in total, and should take about 15 minutes.\n');
fprintf('**********************************\n\n');

% Create a directory for the subject
if ~isfolder(dataDir)
    mkdir(dataDir)
end

% Define the filestem for this psychometric object
psychFileStem = sprintf( [subjectID '_' experimentName ...
    '_direction-' direction] );

% Define the trial label for this sequence
trialLabel = sprintf( [subjectID '_' experimentName ...
    '_direction-' direction '_sequence-%d'],  whichSequence );

% Create or load the psychometric object
filename = fullfile(dataDir,[psychFileStem '.mat']);
if isfile(filename)
    % Load the object
    load(filename,'psychObj');
    % Put in fresh control objects
    psychObj.irCameraObj = irCameraObj;
    psychObj.LightObj = LightObj;
    % Update the trialLabel
    psychObj.trialLabel = trialLabel;
else
    % Create the object
    psychObj = PsychPuffLightLevel(irCameraObj,LightObj,modResult,...
        'trialLabel',trialLabel,...
        'simulateStimuli',simulateModeFlag,'simulateResponse',simulateModeFlag,...
        'verbose',verbosePsychObj);
    % Store the filename
    psychObj.filename = filename;
end

% Loop over trials
thisSequence = sequenceSet{whichSequence};
for ss=1:length(thisSequence)

    % Alert the subject
    Speak('Ready');
    input('');

    % Present the next trial
    psychObj.presentTrial;

end


% Report completion of this sequence
Speak('Done');
fprintf('done.\n');

% empty the AirPuffObj and LightObj handles and save the psychObj
psychObj.irCameraObj = [];
psychObj.LightObj = [];
save(psychObj.filename,'psychObj');

% Clean up
if ~simulateModeFlag

    clear irCameraObj

    LightObj.goDark;
    LightObj.serialClose;
    clear LightObj
end

end % function
