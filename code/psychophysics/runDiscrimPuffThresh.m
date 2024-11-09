function runDiscrimPuffThresh(subjectID,refPuffPSI,varargin)
% Psychometric measurement of discrmination thresholds at a set of
% frequencies for two post-receptoral directions (LMS and L-M).
%
% Examples:
%{
    subjectID = 'PILT_0001';
    NDlabel = '0x5';
    refPuffPSI = 10;
    runDiscrimThreshExperiment(subjectID,NDlabel,refPuffPSI);
%}

% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('dropBoxBaseDir',getpref('combiExperiments','dropboxBaseDir'),@ischar);
p.addParameter('dropBoxSubDir','BLNK_data',@ischar);
p.addParameter('projectName','combiAir',@ischar);
p.addParameter('stimParamsHi',linspace(0,1,51),@isnumeric);
p.addParameter('stimParamsLow',linspace(-1,0,51),@isnumeric);
p.addParameter('nTrialsPerBlock',20,@isnumeric);
p.addParameter('nBlocks',1,@isnumeric);
p.addParameter('verboseCombiAir',false,@islogical);
p.addParameter('verbosePsychObj',true,@islogical);
p.parse(varargin{:})

%  Pull out of the p.Results structure
nTrialsPerBlock = p.Results.nTrialsPerBlock;
nBlocks = p.Results.nBlocks;
verboseCombiAir = p.Results.verboseCombiAir;
verbosePsychObj = p.Results.verbosePsychObj;

% Set our experimentName
experimentName = 'DSCM';

% Set the labels for the high and low stimulus ranges
stimParamLabels = {'stimParamsHi','stimParamsLow'};

% Set a random seed
rng('shuffle');

% Define the modulation and data directories
subjectDir = fullfile(...
    p.Results.dropBoxBaseDir,...
    p.Results.dropBoxSubDir,...,
    p.Results.projectName,...
    subjectID);

% Set up the CombiAir
CombiAirObj = CombiAirControl('verbose',verboseCombiAir);

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

% Prepare to loop over blocks
for bb=1:nBlocks

    % Assemble the psychObj array, looping over the high and low range of
    % the discrimination function
    psychObjArray = {};
    for ss = 1:2

        % Define the filestem for this psychometric object
        dataDir = fullfile(subjectDir,experimentName);
        psychFileStem = [subjectID '_' experimentName ...
            '_refPSI-' num2str(refPuffPSI) ...
            '_' stimParamLabels{ss}];

        % Obtain the relevant stimParam values
        stimParamsDomainList = p.Results.(stimParamLabels{ss});

        % Create or load the psychometric object
        filename = fullfile(dataDir,[psychFileStem '.mat']);
        if isfile(filename)
            % Load the object
            load(filename,'psychObj');
            % Put in the fresh CombiAirObj
            psychObj.CombiAirObj = CombiAirObj;
            % Initiate the CombiAir settings
            psychObj.initializeDisplay;
            % Increment blockIdx
            psychObj.blockIdx = psychObj.blockIdx+1;
            psychObj.blockStartTimes(psychObj.blockIdx) = datetime();
        else
            % Create the object
            psychObj = PsychDiscrimPuffThreshold(CombiAirObj,refPuffPSI,...
                'stimParamsDomainList',stimParamsDomainList,'verbose',verbosePsychObj);
            % Store the filename
            psychObj.filename = filename;
        end

        % Store in the psychObjArray
        psychObjArray{ss} = psychObj;

        % Clear the psychObj
        clear psychObj

    end

    % Start the block
    fprintf('Press enter to start block %d...',bb);
    input('');

    % Store the block start time
    for ss = 1:2
        blockStartTime = datetime();
        psychObjArray{ss}.blockStartTimes(psychObjArray{ss}.blockIdx) = blockStartTime;
    end

    % Present nTrials.
    for ii = 1:nTrialsPerBlock
        psychObjIdx = mod(ii,2)+1;
        psychObjArray{psychObjIdx}.presentTrial
    end

    % Report completion of this block
    fprintf('done.\n');

    % Store the psychObjArray entries
    for ss = 1:2
        % Grab the next psychObj
        psychObj = psychObjArray{ss};
        % empty the CombiAirObj handle and save the psychObj
        psychObj.CombiAirObj = [];
        save(psychObj.filename,'psychObj');
    end

end % block loop

% Clean up
CombiAirObj.serialClose;
clear CombiAirObj

end % function
