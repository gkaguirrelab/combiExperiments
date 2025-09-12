function runPuffLightDiscrim(subjectID,whichDirection,varargin)
% Present trial sequences and record video of the blink response.
%
% Examples:
%{
    subjectID = 'HERO_gka';
    whichDirection = 'LightFlux';
    runPuffLightDiscrim(subjectID,whichDirection);
%}

% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('dropBoxBaseDir',getpref('combiExperiments','dropboxBaseDir'),@ischar);
p.addParameter('dropBoxSubDir','BLNK_data',@ischar);
p.addParameter('projectName','PuffLight',@ischar);
p.addParameter('puffPSISet',[15 30],@isnumeric);
p.addParameter('puffDurSetSecs',[0.05 ,0.05],@isnumeric);
p.addParameter('modContrastLevels',[0,0.1],@isnumeric);
p.addParameter('adaptDurationMins',5,@isnumeric);
p.addParameter('nRunsPerBlock',4,@isnumeric);
p.addParameter('nTrialsPerRun',20,@isnumeric);
p.addParameter('nAdaptBlocks',2,@isnumeric);
p.addParameter('simulateModeFlag',false,@islogical);
p.addParameter('verbosePuffObj',false,@islogical);
p.addParameter('verboseCameraObj',false,@islogical);
p.addParameter('verboseLightObj',false,@islogical);
p.addParameter('verbosePsychObj',true,@islogical);
p.parse(varargin{:})

%  Pull out of the p.Results structure
puffPSISet = p.Results.puffPSISet;
puffDurSetSecs = p.Results.puffDurSetSecs;
modContrastLevels = p.Results.modContrastLevels;
adaptDurationMins = p.Results.adaptDurationMins;
nTrialsPerRun = p.Results.nTrialsPerRun;
nRunsPerBlock = p.Results.nRunsPerBlock;
nAdaptBlocks = p.Results.nAdaptBlocks;
simulateModeFlag = p.Results.simulateModeFlag;
verbosePuffObj = p.Results.verbosePuffObj;
verboseLightObj = p.Results.verboseLightObj;
verboseCameraObj = p.Results.verboseCameraObj;
verbosePsychObj = p.Results.verbosePsychObj;

% Set our experimentName
experimentName = 'puffDiscrim';

% Get the number of puffPSI intensities to be studied
nStimLevels = length(puffPSISet);

% Get the number of contrast levels to be studied
nContrasts = length(modContrastLevels);

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

    % Set the gamma table
    LightObj.setGamma(modResult.meta.cal.processedData.gammaTable);

    % By default, gamma correction is not performed in directMode. Here we
    % turn gamma correction on.
    LightObj.setDirectModeGamma(true);

    % Set up the adaptation ramp properties
    LightObj.setSettings(modResult);
    LightObj.setUnimodal();
    LightObj.goDark;
    LightObj.setWaveformIndex(2); % square-wave
    LightObj.setFrequency(1/3000);
    LightObj.setDuration(adaptDurationMins*60*2);
    LightObj.setPhaseOffset(pi);
    LightObj.setRampIndex(2);
    LightObj.setRampDuration((adaptDurationMins)*60);

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

    % Loop over the pressure levels
    for nn = 1:nStimLevels

        % Define the filestem for this psychometric object
        psychFileStem = sprintf( [subjectID '_' experimentName ...
            '_direction-' whichDirection '_contrast-%2.2f' ...
            '_refPSI-%2.2f_durSecs-%2.3f' ],...
            modContrastLevels(cc),puffPSISet(nn),puffDurSetSecs(nn));

        % Create or load the psychometric object
        filename = fullfile(dataDir,[psychFileStem '.mat']);
        if isfile(filename)
            % Load the object
            load(filename,'psychObj');
        else
            % Create the object
            psychObj = PsychPuffLightDiscrim(...
                AirPuffObj,irCameraObj,puffPSISet(nn),...
                'trialLabel',psychFileStem,...
                'puffDurSecs',puffDurSetSecs(nn),...
                'simulateStimuli',simulateModeFlag,...
                'verbose',verbosePsychObj);
            % Store the filename
            psychObj.filename = filename;
        end

        % Store in the psychObjArray
        psychObjArray{cc,nn} = psychObj;

        % Clear the psychObj
        clear psychObj
    end
end

% Prepare to loop over blocks
for bb = 1:nAdaptBlocks

    % Prepare to loop over contrasts
    for cc = 1:nContrasts

        % Get the contrast level for this block
        thisContrast = modContrastLevels(cc);

        % Set the light contrast level
        if ~simulateModeFlag
            LightObj.stopModulation;
            LightObj.setContrast(thisContrast);
        end

        % Get the first psychObj for this contrast level. We will assign
        % the adaptation recording to this object
        psychObj = psychObjArray{cc,1};

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
        if ~simulateModeFlag
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

            % Clear the psychObj
            clear psychObj
        end

        % Now present a set of runs, each run contains a set of trials
        for ss = 1:nRunsPerBlock

            % Refresh the connections on the objects
            if ~simulateModeFlag
                AirPuffObj.serialClose;
                AirPuffObj = PuffControl('verbose',verbosePuffObj);
                irCameraObj = PuffCameraControl(videoDataPath,'verbose',verboseCameraObj);
                for nn = 1:nStimLevels
                    psychObjArray{cc,nn}.AirPuffObj = AirPuffObj;
                    psychObjArray{cc,nn}.irCameraObj = irCameraObj;
                end
            end

            % Announce we are ready to start
            Speak('Ready');
            fprintf('Press enter to start the run %d...',ss);
            input('');
            pause(3);

            % Create a random ordering of the refPuffPSIset
            puffIdxList = repmat(1:nStimLevels,1,nTrialsPerRun/nStimLevels);
            [~,tmp]=sort(rand(1,nTrialsPerRun));
            puffIdxList = puffIdxList(tmp);

            % Loop over trials in this run
            for tt = 1:nTrialsPerRun

                % Present the next trial
                psychObjArray{cc,puffIdxList(tt)}.presentTrial;

            end

            % Save the psychObjs
            for nn = 1:nStimLevels
                psychObj = psychObjArray{cc,nn};
                psychObj.AirPuffObj = [];
                psychObj.irCameraObj = [];
                save(psychObj.filename,'psychObj');
            end

            % Report completion of this run
            fprintf('done.\n');

        end % loop over runs

        % Stop the modulation
if ~simulateModeFlag        
        LightObj.stopModulation;
end

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
