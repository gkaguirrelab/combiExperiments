function runDiscrimPuffThresh(subjectID,varargin)
% Psychometric measurement of discrmination threshold for simultaneous air
% puffs of varying intensity.
%
% Examples:
%{
    subjectID = 'HERO_gka';
    runDiscrimPuffThresh(subjectID,'simulateFlag',true);
%}

% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('dropBoxBaseDir',getpref('combiExperiments','dropboxBaseDir'),@ischar);
p.addParameter('dropBoxSubDir','BLNK_data',@ischar);
p.addParameter('projectName','PuffLight',@ischar);
p.addParameter('refPuffSetPSI',logspace(log10(5),log10(20),7),@isnumeric);
p.addParameter('stimParamsHi',linspace(0,3,15),@isnumeric);
p.addParameter('stimParamsLow',linspace(-3,0,15),@isnumeric);
p.addParameter('nTrialsPerObj',5,@isnumeric);
p.addParameter('nBlocks',1,@isnumeric);
p.addParameter('useStaircase',false,@islogical);
p.addParameter('simulateFlag',false,@islogical);
p.addParameter('verbosePuffObj',false,@islogical);
p.addParameter('verbosePsychObj',true,@islogical);
p.parse(varargin{:})

%  Pull out of the p.Results structure
nTrialsPerObj = p.Results.nTrialsPerObj;
nBlocks = p.Results.nBlocks;
refPuffSetPSI = p.Results.refPuffSetPSI;
useStaircase = p.Results.useStaircase;
simulateFlag = p.Results.simulateFlag;
verbosePuffObj = p.Results.verbosePuffObj;
verbosePsychObj = p.Results.verbosePsychObj;

% The number of stimulus intensity levels
nLevels = length(refPuffSetPSI);

% Set our experimentName
experimentName = 'DSCM';

% Set the labels for the high and low stimulus ranges
stimParamLabels = {'stimParamsHi','stimParamsLow'};

% Calculate the total number of trials per block
nTrialsPerBlock = nTrialsPerObj * nLevels * length(stimParamLabels);

% Set a random seed
rng('shuffle');

% Define the modulation and data directories
subjectDir = fullfile(...
    p.Results.dropBoxBaseDir,...
    p.Results.dropBoxSubDir,...,
    p.Results.projectName,...
    subjectID);

% Set up the AirPuffObj
AirPuffObj = PuffControl('verbose',verbosePuffObj);

% Set up the CombiLED LightObj
LightObj = [];

% Provide instructions
fprintf('**********************************\n');
fprintf('On each of many trials you will be presented with 2 air puffs\n');
fprintf('Your job is to indicate which puff was stronger by pressing the\n');
fprintf('1 or 2 key on the numeric key pad. Each block has %d trials after\n',nTrialsPerBlock);
fprintf('which you may take a brief break. There are a total of %d blocks.\n',nBlocks);
fprintf('**********************************\n\n');

% Create a directory for the subject
dataDir = fullfile(subjectDir,experimentName);
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

    for ss = 1:2

        % Define the filestem for this psychometric object
        psychFileStem = sprintf( [subjectID '_' experimentName ...
            '_refPSI-%2.2f_' stimParamLabels{ss}],refPuffPSI );

        % Obtain the relevant stimParam values
        stimParamsDomainList = p.Results.(stimParamLabels{ss});

        % Create or load the psychometric object
        filename = fullfile(dataDir,[psychFileStem '.mat']);
        if isfile(filename)
            % Load the object
            load(filename,'psychObj');
            % Put in the fresh AirPuffObj
            psychObj.AirPuffObj = AirPuffObj;
            % Initiate the CombiAir settings
            psychObj.initializeDisplay;
            % Increment blockIdx
            psychObj.blockIdx = psychObj.blockIdx+1;
            psychObj.blockStartTimes(psychObj.blockIdx) = datetime();
            % Update the useStaircase flag in case this has changed
            psychObj.useStaircase = useStaircase;
        else
            % Create the object
            psychObj = PsychDiscrimPuffThreshold(AirPuffObj,LightObj,refPuffPSI,...
                'stimParamsDomainList',stimParamsDomainList,...
                'simulateStimuli',simulateFlag,'simulateResponse',simulateFlag,...
                'verbose',verbosePsychObj,'useStaircase',useStaircase);
            % Store the filename
            psychObj.filename = filename;
        end

        % Store in the psychObjArray
        psychObjArray{end+1} = psychObj;

        % Clear the psychObj
        clear psychObj

    end
end

nPsychObjs = length(psychObjArray);
assert(nPsychObjs == nLevels*2);

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

    % Present nTrialsPerObj * nPsychObjs in permuted sets
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
        % empty the AirPuffObj handle and save the psychObj
        psychObj.AirPuffObj = [];
        save(psychObj.filename,'psychObj');
    end

end % block loop

% Clean up
AirPuffObj.serialClose;
clear AirPuffObj

end % function
