function runParametricBlinkResponse(subjectID,whichDirection,varargin)
% Present trial sequences and record video of the blink response.
%
% Examples:
%{
    subjectID = 'HERO_gka';
    whichDirection = 'LightFlux';
    runParametricBlinkResponse(subjectID,whichDirection);
%}

% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('dropBoxBaseDir',getpref('combiExperiments','dropboxBaseDir'),@ischar);
p.addParameter('dropBoxSubDir','BLNK_data',@ischar);
p.addParameter('projectName','PuffLight',@ischar);
p.addParameter('puffPSISet',logspace(log10(5),log10(30),5),@isnumeric);
p.addParameter('puffDurSecsSet',ones(1,5)*0.075,@isnumeric);
p.addParameter('modContrastLevels',[0,0.25],@isnumeric);
p.addParameter('adaptDurationMins',5,@isnumeric);
p.addParameter('nSequences',4,@isnumeric);
p.addParameter('nAdaptBlocks',2,@isnumeric);
p.addParameter('simulateModeFlag',false,@islogical);
p.addParameter('verbosePuffObj',false,@islogical);
p.addParameter('verboseCameraObj',true,@islogical);
p.addParameter('verboseLightObj',false,@islogical);
p.addParameter('verbosePsychObj',true,@islogical);
p.parse(varargin{:})

%  Pull out of the p.Results structure
puffPSISet = p.Results.puffPSISet;
puffDurSecsSet = p.Results.puffDurSecsSet;
modContrastLevels = p.Results.modContrastLevels;
adaptDurationMins = p.Results.adaptDurationMins;
nAdaptBlocks = p.Results.nAdaptBlocks;
nSequences = p.Results.nSequences;
simulateModeFlag = p.Results.simulateModeFlag;
verbosePuffObj = p.Results.verbosePuffObj;
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

% Set our experimentName
experimentName = 'blinkResponse';

% Get the number of contrast levels to be studied
nContrasts = length(modContrastLevels);

% Calculate the total number of trials per block, and make sure we have the
% right number of levels
nTrialsPerSequence = length(puffPSISet)^2 +1;
assert(all(cellfun(@(x) length(x)==nTrialsPerSequence,sequenceSet)));

% Make sure we have enough sequences given nSequences
assert(nSequences <= length(sequenceSet));

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
    irCameraObj = PuffCameraControl(videoDataPath,'verbose',verboseCameraObj);

    % Set up the CombiLED LightObj
    LightObj = CombiLEDcontrol('verbose',verboseLightObj);

    % By default, gamma correction is not performed in directMode. Here we
    % turn gamma correction on.
    %% Calling this is causing some kind of serial communication error in
    %% later CombiLED commands. Turning this off for now as it doesn't
    %% really matter for the light flux measurements
    %{
    LightObj.setDirectModeGamma(true);
    %}

    % Set the gamma table
    LightObj.setGamma(modResult.meta.cal.processedData.gammaTable);

    % Set up the adaptation ramp properties
    LightObj.setSettings(modResult);
    LightObj.setUnimodal();
    LightObj.goDark;
    LightObj.setWaveformIndex(2); % square-wave
    LightObj.setFrequency(1/3000);
    LightObj.setDuration(adaptDurationMins*60*2);
    LightObj.setPhaseOffset(pi);
    LightObj.setRampIndex(2);
    LightObj.setRampDuration((adaptDurationMins-1)*60);

else
    AirPuffObj = [];
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

% Assemble the psychObj array for the modulation contrast levels
psychObjArray = {};
for cc = 1:nContrasts

    % Define the filestem for this psychometric object
    psychFileStem = sprintf( [subjectID '_' experimentName ...
        '_direction-' whichDirection '_contrast-%2.2f' ],...
        modContrastLevels(cc));

    % Create or load the psychometric object
    filename = fullfile(dataDir,[psychFileStem '.mat']);
    if isfile(filename)
        % Load the object
        load(filename,'psychObj');
    else
        % Create the object
        psychObj = ParametricBlinkResponse(...
            AirPuffObj,irCameraObj,...
            'puffPSISet',puffPSISet,...
            'puffDurSecsSet',puffDurSecsSet,...
            'simulateStimuli',simulateModeFlag,...
            'verbose',verbosePsychObj);
        % Store the filename
        psychObj.filename = filename;
    end

    % Store in the psychObjArray
    psychObjArray{end+1} = psychObj;

    % Clear the psychObj
    clear psychObj
end

% Prepare to loop over blocks
for bb = 1:nAdaptBlocks

    % Prepare to loop over contrasts
    for cc = 1:nContrasts

        % Get the contrast level for this block
        thisContrast = modContrastLevels(cc);

        % Set the light contrast level
        LightObj.stopModulation;
        LightObj.setContrast(thisContrast);

        % Get the psychObj for this contrast level
        psychObj = psychObjArray{cc};

        % Refresh the irObj
        if ~simulateModeFlag
            irCameraObj = PuffCameraControl(videoDataPath,'verbose',verboseCameraObj);
            psychObj.irCameraObj = irCameraObj;
        end

        % Wait for the subject to start adaptation
        Speak('adapt');
        fprintf('Press enter to start adaptation...');
        input('');

        % Start the light ramp
        LightObj.startModulation;

        % Count down the minutes and record a video during each minute
        for mm = 1:adaptDurationMins
            % Define the label to be used for the adaptation video recording
            recordLabel = sprintf( [subjectID '_' experimentName ...
                '_direction-' whichDirection '_contrast-%2.2f_block-%d_adapt-%d' ],...
                thisContrast,bb,mm);
            Speak(sprintf('%d',adaptDurationMins-(mm-1)));
            psychObj.recordAdaptPeriod(recordLabel,55);
            pause(5);
        end

        % Use direct mode to set the CombiLED to the light level we want
        % for this sequence
        settings = thisContrast .* (modResult.settingsHigh - modResult.settingsLow) + modResult.settingsLow;
        LightObj.setPrimaries(settings);

        % Now present a set of sequences, each of which should be about 2
        % minutes in duration
        for ss = 1:nSequences

            % Refresh the connections on the objects
            if ~simulateModeFlag
                AirPuffObj.serialClose;
                AirPuffObj = PuffControl('verbose',verbosePuffObj);
                irCameraObj = PuffCameraControl(videoDataPath,'verbose',verboseCameraObj);
                psychObj.AirPuffObj = AirPuffObj;
                psychObj.irCameraObj = irCameraObj;
            end

            % Get this sequence
            sequence = sequenceSet{ss};

            % Define the trialLabelStem that will be used to save videos
            trialLabelStem = sprintf( [subjectID '_' experimentName ...
                '_direction-' whichDirection '_contrast-%2.2f_block-%d_sequence-%d' ],...
                thisContrast,bb,ss);

            % Update the psychObject to use this trialLabel
            psychObj.trialLabelStem = trialLabelStem;

            % Announce we are ready to start
            Speak('Ready');
            fprintf('Press enter to start the blink sequence %d...',ss);
            input('');
            pause(3);

            % Present the blink sequence puffs
            psychObj.presentTrialSequence(sequence);

            % Save the psychObj
            psychObj.AirPuffObj = [];
            psychObj.irCameraObj = [];
            save(psychObj.filename,'psychObj');

            % Report completion of this sequence
            fprintf('done.\n');

        end % loop over sequences

        % Stop the modulation
        LightObj.stopModulation;

    end % loop over contrasts

end % loop over adaptation blocks

% Report done
Speak('done');

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
