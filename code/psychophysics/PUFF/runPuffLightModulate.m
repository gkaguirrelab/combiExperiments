function runPuffLightModulate(subjectID,varargin)
% An experiment in which the right eye of the participant is recorded while
% they view a stimulus that provides a sinusoidal modulation of
% photoreceptor contrast. During the measurement the participant performs a
% cover task in which they respond to a brief dimming of the stimulus
% field.
%
% The session begins with a 2 minute period of adaptation to the
% background. This is followed by 24 stimulation periods, each 60 seconds
% in duration (plus 5 seconds of an inter-trial-interval for camera
% recording clean up). There are 16 different stimulus conditions,
% consisting of a LightFLux, Mel, LMS, and S-directed modulation, crossed
% with 0.2 and 0.4 photoreceptor contrast levels, crossed with forward and
% reversed phases. Presentation order of these 16 trials is randomized.
% Total data collection is about 18 minutes.
%
% Examples:
%{
    subjectID = 'TEST_001';
    runPuffLightModulate(subjectID,'simulateModeFlag',false);
%}

% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('dropBoxBaseDir',getpref('combiExperiments','dropboxBaseDir'),@ischar);
p.addParameter('dropBoxSubDir','BLNK_data',@ischar);
p.addParameter('projectName','PuffLight',@ischar);
p.addParameter('directions',{'Mel','LMS','S_peripheral','LightFlux'},@iscell);
p.addParameter('photoreceptorContrasts',[0.2,0.4],@isnumeric);
p.addParameter('phases',[0,pi],@isnumeric);
p.addParameter('nTrialsPerObj',1,@isnumeric);
p.addParameter('nBlocks',1,@isnumeric);
p.addParameter('adaptDurationMins',2,@isnumeric);
p.addParameter('useKeyboardFlag',false,@islogical);
p.addParameter('simulateModeFlag',false,@islogical);
p.addParameter('verboseLightObj',false,@islogical);
p.addParameter('verboseCameraObj',false,@islogical);
p.addParameter('verbosePsychObj',true,@islogical);
p.parse(varargin{:})

% Pull variables out of the p.Results structure
nTrialsPerObj = p.Results.nTrialsPerObj;
nBlocks = p.Results.nBlocks;
directions = p.Results.directions;
contrasts = p.Results.photoreceptorContrasts;
phases = p.Results.phases;
adaptDurationMins = p.Results.adaptDurationMins;
useKeyboardFlag = p.Results.useKeyboardFlag;
simulateModeFlag = p.Results.simulateModeFlag;
verboseLightObj = p.Results.verboseLightObj;
verboseCameraObj = p.Results.verboseCameraObj;
verbosePsychObj = p.Results.verbosePsychObj;

% The number of modulation directions and phases we will study
nDirections = length(directions);
nContrasts = length(contrasts);
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
    irCameraObj = PuffCameraControl(experimentName,subjectID);

    % Set up the CombiLED LightObj
    LightObj = CombiLEDcontrol('verbose',verboseLightObj);

    % Set the gamma table
    LightObj.setGamma(modResult.meta.cal.processedData.gammaTable);

else
    irCameraObj = [];
    LightObj = [];
end

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

    % Loop over photoreceptor contrast levels
    for cc = 1:nContrasts

        % Get this photoreceptor contrast
        thisPhotoContrast = contrasts(cc);

        % Loop over the phases
        for pp = 1:nPhases

            % Define the filestem for this psychometric object
            psychFileStem = sprintf( [subjectID '_' experimentName ...
                '_direction-' whichDirection '_contrast-%2.2f_phase-%2.2f'], thisPhotoContrast, phases(pp) );

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
                % Calculate the modulation contrast needed to produce the
                % desired photoreceptor contrast
                maxPhotoContrast = mean(abs(modResult.contrastReceptorsBipolar(modResult.meta.whichReceptorsToTarget)));
                modContrast = thisPhotoContrast / maxPhotoContrast;
                % Create the object
                psychObj = PsychPuffLightModulate(irCameraObj,LightObj,modResult,...
                    'trialLabel',psychFileStem,...
                    'lightModContrast',modContrast,...
                    'lightModPhase',phases(pp),...
                    'useKeyboardFlag',useKeyboardFlag,...
                    'simulateStimuli',simulateModeFlag,...
                    'simulateResponse',simulateModeFlag,...
                    'verbose',verbosePsychObj);
                % Store the filename
                psychObj.filename = filename;
            end

            % Store in the psychObjArray
            psychObjArray{end+1} = psychObj;

            % Clear the psychObj
            clear psychObj

        end % phases

    end % contrasts

end % directions

% How many psychObjs do we have
nPsychObjs = length(psychObjArray);


%% Adapt
% Grab the first psychObj; we will assign the adaptation period to this
psychObj = psychObjArray{1};

% Initialize the display
psychObj.initializeDisplay;

% refresh the irObj
if ~simulateModeFlag
    irCameraObj = PuffCameraControl(experimentName,subjectID,'verbose',verboseCameraObj);
    psychObj.irCameraObj = irCameraObj;
end

% Provide instructions
fprintf('**********************************\n');
fprintf('After a 2 minutes of adaptation to the light field, you will\n');
fprintf('perform 16 tests, each 60 seconds in duration. During the test\n');
fprintf('your job is to monitor for a sudden, brief dimming of the light.\n');

if useKeyboardFlag
    fprintf('If you see this dimming, press the space bar. Press return\n');
    fprintf('when ready for the next trial.\n');
else
    fprintf('If you see this dimming, press either of the two upper bumper\n');
    fprintf('buttons on the game pad. Press any of the four colored buttons\n');
    fprintf('on the front of the game pad when ready for the next trial.\n');
end

fprintf('You may be aware of the light slowly changing in other ways, such\n');
fprintf('as overall brightness or color. Do your best to ignore these\n');
fprintf('changes. Instead, keep your eyes open and watch closely for the\n');
fprintf('brief dimming events.\n');
fprintf('**********************************\n\n');


% Wait for the subject to start adaptation
Speak('adapt');
if useKeyboardFlag
    fprintf('Press enter to start adaptation for %d minutes...',adaptDurationMins);
    input('');
else
    fprintf('Press a front button to start adaptation for %d minutes...\n',adaptDurationMins);
    getGamepadResponse(Inf,[1 2 3 4]);
end

% Start the adaptation period
if ~simulateModeFlag

    % Count down the minutes and record a video during each minute
    for mm = 1:adaptDurationMins
        % Define the label to be used for the adaptation video recording
        recordLabel = sprintf( [subjectID '_' experimentName ...
            '_direction-' whichDirection '_session_%d_adapt-%d' ],psychObj.adaptIdx+1,mm);
        Speak(sprintf('%d',adaptDurationMins-(mm-1)));
        psychObj.recordAdaptPeriod(recordLabel,55);
        pause(5);
    end
end


%% Loop over blocks
for bb=1:nBlocks

    % Define a random ordering of the psychObjs
    objIdxList = repmat(1:nPsychObjs,1,nTrialsPerObj);
    [~,tmp]=sort(rand(1,length(objIdxList)));
    objIdxList = objIdxList(tmp);

    % Get an updated irCameraObj
    if ~simulateModeFlag
        irCameraObj = PuffCameraControl(experimentName,subjectID,'verbose',verboseCameraObj);
    end

    % Loop over trials in this run
    for tt = 1:length(objIdxList)

        % Update the camera and light objects
        if ~simulateModeFlag
            psychObjArray{objIdxList(tt)}.irCameraObj = irCameraObj;
            psychObjArray{objIdxList(tt)}.LightObj = LightObj;
        end

        % Alert the subject
        Speak(sprintf('trial %d of %d',tt,length(objIdxList)));
        if useKeyboardFlag
            fprintf('Press enter to start...');
            input('');
        else
            fprintf('Press a front button to start\n');
            getGamepadResponse(Inf,[1 2 3 4]);
        end

        % Present the next trial
        psychObjArray{objIdxList(tt)}.presentTrial;

    end

    % Report completion of this block
    Speak('done.');
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
