function runDCPT_Null(subjectID,NDlabel,varargin)
% Function to run nulling of chromatic and achromatic components of
% modulations. Switches between 2 combiLEDs (eyes). The observer is invited to adjust the weight of
% silencing modulation direction that is added or removed from the source
% modulation direction to null a percetual feature.
%
% A typical application would be to pass an L-M "source" modulation and an
% M-cone isolating "silencing" modulation, with the goal of nulling
% a residual luminance component.

%Parse parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('dropBoxBaseDir',getpref('combiExperiments','dropboxBaseDir'),@ischar);
p.addParameter('dropBoxSubDir','FLIC_data',@ischar);
p.addParameter('projectName','combiLED',@ischar);
p.addParameter('stimFreqHz',24,@isnumeric);
p.addParameter('nTrials',12,@isnumeric);
p.addParameter('modDirections',{'LminusM_wide_ND', 'L_wide'},@iscell);

%  Pull out of the p.Results structure
%why do we have to pull things out of the struct? Jus so it is shorter?
nTrials = p.Results.nTrials;
stimFreqHz = p.Results.stimFreqHz;
modDirections = p.Results.modDirections;

% Set our experimentName
experimentName = 'DCPT_null';

% Define the modulation and data directories
subjectDir = fullfile(...
    p.Results.dropBoxBaseDir,...
    p.Results.dropBoxSubDir,...
    p.Results.projectName,...
    subjectID);

% Define the full paths to the modResult files
combiLEDLabelSet = {'C','D'};

for cc = 1:length(combiLEDLabelSet)
    for dd = 1:2
        modResultFiles{cc,dd} = ...
            fullfile(subjectDir,[modDirections{dd} '_ND' NDlabel],['modResult_' combiLEDLabelSet{cc} '.mat']);
    end
end

% Load modResult files and extract the calibrations. We need this to
% obtain a gamma table to pass to the combiLEDs, and this property of the
% device does not change with modulation direction
% CombiLED C
load(modResultFiles{1,1},'sourceModResult');
calC = sourceModResult.meta.cal;

% CombiLED D
load(modResultFiles{2,1},'sourceModResult');
calD = sourceModResult.meta.cal;

% Set up the CombiLED
if simulateStimuli
    CombiLEDObj = {};
else
    % Open the CombiLED
    CombiLEDObj{1} = CombiLEDcontrol('verbose',verboseCombiLED);
    CombiLEDObj{2} = CombiLEDcontrol('verbose',verboseCombiLED);

    % Check the identifierString and swap objects if needed
    if CombiLEDObj{1}.identifierString == "A10L31XZ" % wrong identifier
        % Swap the objects
        tempObj = CombiLEDObj{1};
        CombiLEDObj{1} = CombiLEDObj{2};
        CombiLEDObj{2} = tempObj;
    end

    % Update the gamma table
    CombiLEDObj{1}.setGamma(calC.processedData.gammaTable);
    CombiLEDObj{2}.setGamma(calD.processedData.gammaTable);
end

% Provide instructions

fprintf('**********************************\n');
fprintf('On each of many trials you will be presented with flicker\n');
fprintf('on the left and right. Your job is to step forward\n');
fprintf('by pressing the right arrow key until the flicker\n');
fprintf('is as low contrast as possible. You can step backwards\n');
fprintf('with the left arrow ONCE if you went too far. Press return to end.\n');
fprintf('**********************************\n\n');

% Assemble the psychObj array
psychObjArray = cell(length(combiLEDLabelSet), length(modDirections));

for whichCombi=1:2

    % Load the previously generated modResult files for this trial
    load(modResultFiles{1,whichCombi},'modResult');
    sourceModResult = modResult; clear modResult;
    load(modResultFiles{2,whichCombi},'modResult');
    silencingModResult = modResult; clear modResult;

    % Create a directory for the subject
    dataDir = fullfile(subjectDir,['LMinusMNull_ND' NDlabel],experimentName);
    if ~isfolder(dataDir)
        mkdir(dataDir)
    end

    % Define the filestem for this psychometric object
    dataDir = fullfile(subjectDir,['LMinusMNull_ND' NDlabel],experimentName);
    psychFileStem = [subjectID '_LMinusMNull_' experimentName, ...
        'FreqHz_' num2str(stimFreqHz)];

    % Create or load the psychometric object
    filename = fullfile(dataDir,[psychFileStem '.mat']);
    if isfile(filename)
        % Load the object
        load(filename,'psychObj');
        % Put in the fresh CombiLEDObjs
        psychObj.CombiLEDObj = CombiLEDObj{whichCombi};
    else
        % Create the object
        psychObj = PsychFlickerNull(CombiLEDObj{whichCombi}, sourceModResult, silencingModResult);
        % Store the filename
        psychObj.filename = filename;
    end

    % Initialize Display
    psychObj.initializeDisplay;

    % Store in the psychObjArray
    psychObjArray{whichCombi} = psychObj;

    % Clear the psychObj
    clear psychObj

end

for tt = 1:nTrials
    psychObjArray{testFreqHzIndex(ii)}.presentTrial();
end

% Report completion of this block
fprintf('done.\n');

% Store the psychObjArray entries
for whichCombi = 1:2
    % Grab the next psychObj
    psychObj = psychObjArray{whichCombi};
    % empty the CombiLEDObj handles and save the psychObj
    psychObj.CombiLEDObj = [];
    save(psychObj.filename,'psychObj');
end


% Clean up
if ~simulateStimuli
    for whichCombi = 1:2
        CombiLEDObj{whichCombi}.goDark;
        CombiLEDObj{whichCombi}.serialClose;
    end
end
clear CombiLEDObj


end