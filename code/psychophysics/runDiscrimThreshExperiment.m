function runDiscrimThreshExperiment(subjectID,NDlabel,varargin)
% Psychometric measurement of discrmination thresholds at a set of
% frequencies for two post-receptoral directions (LMS and L-M).
%
% Examples:
%{
    subjectID = 'PILT_0001';
    NDlabel = '0x5';
    runDiscrimThreshExperiment(subjectID,NDlabel);
%}

% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('dropBoxBaseDir',getpref('combiExperiments','dropboxBaseDir'),@ischar);
p.addParameter('dropBoxSubDir','FLIC_data',@ischar);
p.addParameter('projectName','combiLED',@ischar);
p.addParameter('modDirections',{'LminusM_wide','LightFlux'},@iscell);
p.addParameter('targetPhotoreceptorContrast',[0.075,0.333],@isnumeric);
p.addParameter('stimParamsHi',{linspace(0,1,51),linspace(0,1,51)},@isnumeric);
p.addParameter('stimParamsLow',{linspace(-1,0,51),linspace(-1,0,51)},@isnumeric);
p.addParameter('refFreqValuesHz',[2 10],@isnumeric);
p.addParameter('nTrialsPerBlock',32,@isnumeric);
p.addParameter('nBlocks',10,@isnumeric);
p.addParameter('verboseCombiLED',false,@islogical);
p.addParameter('verbosePsychObj',true,@islogical);
p.addParameter('updateFigures',false,@islogical);
p.parse(varargin{:})

%  Pull out of the p.Results structure
refFreqValuesHz = p.Results.refFreqValuesHz;
nTrialsPerBlock = p.Results.nTrialsPerBlock;
nBlocks = p.Results.nBlocks;
modDirections = p.Results.modDirections;
targetPhotoreceptorContrast = p.Results.targetPhotoreceptorContrast;
verboseCombiLED = p.Results.verboseCombiLED;
verbosePsychObj = p.Results.verbosePsychObj;

% How many frequencies will we interleave and test?
nRefFreqs = length(refFreqValuesHz);

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

% Load a modResult file and extract the calibration. We need this to
% obtain a gamma table to pass to the combiLED, and this property of the
% device does not change with modulation direction
modResultFile = ...
    fullfile(subjectDir,[modDirections{1} '_ND' NDlabel],'modResult.mat');
load(modResultFile,'modResult');
cal = modResult.meta.cal;

% Set up the CombiLED
CombiLEDObj = CombiLEDcontrol('verbose',verboseCombiLED);

% Update the gamma table
CombiLEDObj.setGamma(cal.processedData.gammaTable);

% Provide instructions
fprintf('**********************************\n');
fprintf('On each of many trials you will be presented with 2 seconds of flicker\n');
fprintf('during each of two intervals. Your job is to indicate which interval\n');
fprintf('had the faster flickering stimulus by pressing the 1 or 2 key on the\n');
fprintf('numeric key pad. Press any other key (e.g., enter) when you are ready\n');
fprintf('to go on to the next trial. Each block has %d trials in a row after\n',nTrialsPerBlock);
fprintf('which you may take a brief break. There are a total of %d blocks.\n',nBlocks);
fprintf('**********************************\n\n');

% Prepare to loop over blocks
for bb=1:nBlocks

    % Switch back and forth between the modulation directions
    directionIdx = mod(bb,2)+1;

    % Which direction we will use this time
    modResultFile = ...
        fullfile(subjectDir,[modDirections{directionIdx} '_ND' NDlabel],'modResult.mat');

    % Load the previously generated modResult file for this direction
    load(modResultFile,'modResult');


    % Create a directory for the subject
    dataDir = fullfile(subjectDir,[modDirections{directionIdx} '_ND' NDlabel],experimentName);
    if ~isfolder(dataDir)
        mkdir(dataDir)
    end

    % Loop through the set of psychObjs we require, one for each reference
    % frequency to be tested
    psychObjArray = {};
    for ff = 1:nRefFreqs

        % Loop over the high and low range of the discrimination function
        for ss = 1:2

        % Define the filestem for this psychometric object
        dataDir = fullfile(subjectDir,[modDirections{directionIdx} '_ND' NDlabel],experimentName);
        psychFileStem = [subjectID '_' modDirections{directionIdx} '_' experimentName ...
            '_' strrep(num2str(targetPhotoreceptorContrast(directionIdx)),'.','x') ...
            '_refFreq-' num2str(refFreqValuesHz(ff)) 'Hz' ...
            '_' stimParamLabels{ss}];

        % Calculate the testContrast
        maxPhotoreceptorContrast = mean(abs(modResult.contrastReceptorsBipolar(modResult.meta.whichReceptorsToTarget)));
        testContrast = targetPhotoreceptorContrast(directionIdx) / maxPhotoreceptorContrast;

        % Obtain the relevant stimParam values
        stimParamsDomainList = p.Results.(stimParamLabels{ss}){directionIdx};

        % Create or load the psychometric object
        filename = fullfile(dataDir,[psychFileStem '.mat']);
        if isfile(filename)
            % Load the object
            load(filename,'psychObj');
            % Put in the fresh CombiLEDObj
            psychObj.CombiLEDObj = CombiLEDObj;
            % Initiate the CombiLED settings
            psychObj.initializeDisplay;
            % Increment blockIdx
            psychObj.blockIdx = psychObj.blockIdx+1;
            psychObj.blockStartTimes(psychObj.blockIdx) = datetime();
        else
            % Create the object
            psychObj = PsychDiscrimThreshold(CombiLEDObj,modResult,refFreqValuesHz(ff),...
                'refContrast',testContrast,'testContrast',testContrast,...
                'stimParamsDomainList',stimParamsDomainList,'verbose',verbosePsychObj);
        end

        % Store in the psychObjArray
        psychObjArray{end+1} = psychObj;

        % Clear the psychObj
        clear psychObj
        end
    end

    % Start the block
    fprintf('Press enter to start block %d...',bb);
    input('');

    % Store the block start time
    for pp = 1:nRefFreqs
        blockStartTime = datetime();
        psychObjArray{pp}.blockStartTimes(psychObjArray{pp}.blockIdx) = blockStartTime;
    end

    % Present nTrials.
    for ii = 1:nTrialsPerBlock
        psychObjIdx = mod(ii,nRefFreqs*2)+1;
        psychObjArray{psychObjIdx}.presentTrial
    end

    % Report completion of this block
    fprintf('done.\n');

    % Store the psychObjArray entries
    for pp = 1:nRefFreqs*2
        psychObj = psychObjArray{pp};
        % empty the CombiLEDObj handle and save the psychObj
        psychObj.CombiLEDObj = [];
        save(filename,'psychObj');
    end

end % block loop

end % function
