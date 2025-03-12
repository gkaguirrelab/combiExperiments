function runDichopticFlickerThresh(subjectID,NDlabel,NDlabelB,refFreqHz,varargin)
% Psychometric measurement of discrmination thresholds at a set of
% frequencies for two post-receptoral directions (LMS and L-M).
%
% Examples:
%{
    subjectID = 'PILT_0001';
    NDlabel = '0x5';
    refFreqHz = [24,12,6,3,1.5];
    runDiscrimThreshExperiment(subjectID,NDlabel,refFreqHz);
%}

% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('dropBoxBaseDir',getpref('combiExperiments','dropboxBaseDir'),@ischar);
p.addParameter('dropBoxSubDir','FLIC_data',@ischar);
p.addParameter('projectName','combiLED',@ischar);
p.addParameter('modDirections',{'LminusM_wide','LightFlux'},@iscell);
p.addParameter('targetPhotoreceptorContrast',[0.075,0.05],@isnumeric); %light flux was .333 but there was a lot of entoptic phenomena
p.addParameter('stimParamsHi',{linspace(0,5,51),linspace(0,5,51)},@isnumeric);
p.addParameter('stimParamsLow',{linspace(-5,0,51),linspace(-5,0,51)},@isnumeric);
p.addParameter('nTrialsPerBlock',30,@isnumeric);
p.addParameter('nBlocks',10,@isnumeric);
p.addParameter('useStaircase',false,@islogical);
p.addParameter('verboseCombiLED',false,@islogical);
p.addParameter('verbosePsychObj',true,@islogical);
p.addParameter('simulateResponse',false,@islogical);
p.addParameter('simulateStimuli',false,@islogical);
p.addParameter('randomCombi',true,@islogical);
p.parse(varargin{:})

%  Pull out of the p.Results structure
nTrialsPerBlock = p.Results.nTrialsPerBlock;
nBlocks = p.Results.nBlocks;
useStaircase = p.Results.useStaircase;
modDirections = p.Results.modDirections;
targetPhotoreceptorContrast = p.Results.targetPhotoreceptorContrast;
verboseCombiLED = p.Results.verboseCombiLED;
verbosePsychObj = p.Results.verbosePsychObj;
simulateResponse = p.Results.simulateResponse;
simulateStimuli = p.Results.simulateStimuli;
randomCombi = p.Results.randomCombi;

% Set our experimentName
experimentName = 'DUAL';

% Set the labels for the high and low stimulus ranges
stimParamLabels = {'stimParamsHi','stimParamsLow'};

% Set a random seed
rng('shuffle');

% Define the modulation and data directories
subjectDir = fullfile(...
    p.Results.dropBoxBaseDir,...
    p.Results.dropBoxSubDir,...
    p.Results.projectName,...
    subjectID);

% Load modResult files and extract the calibrations. We need this to
% obtain a gamma table to pass to the combiLEDs, and this property of the
% device does not change with modulation direction
% CombiLED A
modResultFileA = ...
    fullfile(subjectDir,[modDirections{1} '_ND' NDlabel],'modResult.mat');
load(modResultFileA,'modResult');
calA = modResult.meta.cal;

% CombiLED B
modResultFileB = ...
    fullfile(subjectDir,[modDirections{1} '_ND' NDlabelB],'modResult.mat');
load(modResultFileB,'modResult');
calB = modResult.meta.cal;

% Set up the CombiLED
if simulateStimuli
    CombiLEDObjA = [];
    CombiLEDObjB = [];
else
    % Open the CombiLED
    CombiLEDObjA = CombiLEDcontrol('verbose',verboseCombiLED);
    CombiLEDObjB = CombiLEDcontrol('verbose',verboseCombiLED);

    % Check the identifierString and swap objects if needed
    if CombiLEDObjA.identifierString == "B000JA8P" % wrong identifier
        % Swap the objects
        tempObj = CombiLEDObjA;
        CombiLEDObjA = CombiLEDObjB;
        CombiLEDObjB = tempObj;
    end

    % Update the gamma table
    CombiLEDObjA.setGamma(calA.processedData.gammaTable);
    CombiLEDObjB.setGamma(calB.processedData.gammaTable);
end

% Provide instructions
fprintf('**********************************\n');
fprintf('On each of many trials you will be presented with 2 seconds of flicker\n');
fprintf('during each of two intervals. Your job is to indicate which interval\n');
fprintf('had the faster flickering stimulus by pressing the 1 or 2 key on the\n');
fprintf('numeric key pad. Each block has %d trials in a row after\n',nTrialsPerBlock);
fprintf('which you may take a brief break. There are a total of %d blocks.\n',nBlocks);
fprintf('**********************************\n\n');

% Prepare to loop over blocks
for bb=1:nBlocks

%% Comment out switching between blocks
% For now, just study directionIdx = 2 (i.e., LightFLux)
%{    
    % Switch back and forth between the modulation directions
    directionIdx = mod(bb,2)+1;
%}
    directionIdx = 2;

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

    % Assemble the psychObj array, looping over the high and low range of
    % the discrimination function AND the reference frequencies
    psychObjArray = cell(2, length(refFreqHz));
    for ss = 1:2
        for rr = 1:length(refFreqHz)

            % Define the filestem for this psychometric object
            dataDir = fullfile(subjectDir,[modDirections{directionIdx} '_ND' NDlabel],experimentName);
            psychFileStem = [subjectID '_' modDirections{directionIdx} '_' experimentName ...
                '_' strrep(num2str(targetPhotoreceptorContrast(directionIdx)),'.','x') ...
                '_refFreq-' num2str(refFreqHz(rr)) 'Hz' ...
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
                % Put in the fresh CombiLEDObjs
                psychObj.CombiLEDObjA = CombiLEDObjA;
                psychObj.CombiLEDObjB = CombiLEDObjB;
                % Increment blockIdx
                psychObj.blockIdx = psychObj.blockIdx+1;
                psychObj.blockStartTimes(psychObj.blockIdx) = datetime();
                % Update the useStaircase flag in case this has changed
                psychObj.useStaircase = useStaircase;
                % Update the simulate stimuli and response flags in case this has changed
                psychObj.simulateResponse = simulateResponse;
                psychObj.simulateStimuli = simulateStimuli;
                % Update the random combi setting
                psychObj.randomCombi = randomCombi;
            else
                % Create the object
                psychObj = PsychDichopticFlickerDiscrim(CombiLEDObjA, CombiLEDObjB, modResult,refFreqHz(rr),...
                    'refContrast',testContrast,'testContrast',testContrast,...
                    'stimParamsDomainList',stimParamsDomainList,'verbose',verbosePsychObj, ...
                    'simulateResponse',simulateResponse,'simulateStimuli',simulateStimuli,...
                    'useStaircase', useStaircase, 'randomCombi', randomCombi);
                % Store the filename
                psychObj.filename = filename;
            end

            % Store in the psychObjArray
            psychObjArray{ss, rr} = psychObj;

            % Clear the psychObj
            clear psychObj

        end

    end

    % Initialize the display for one of the psychObj elements. This routine
    % assumes that all of the psychObj elements that will be called during
    % the block use the same modulation, modulation background, temporal
    % profile (i.e., sinusoid), and trial duration.
    psychObjArray{1,1}.initializeDisplay;

    % Start the block
    fprintf('Press enter to start block %d...',bb);
    input('');

    % Store the block start time
    for ss = 1:2
        for rr = 1:length(refFreqHz)
            blockStartTime = datetime();
            psychObjArray{ss, rr}.blockStartTimes(psychObjArray{ss,rr}.blockIdx) = blockStartTime;
        end
    end

    % Verify that the number of trials per block is compatible with the number
    % of reference frequencies. 
    if mod(nTrialsPerBlock, length(refFreqHz) * 2) ~= 0
        error(['The number of trials must be even and a ' ...
            'multiple of the number of reference frequencies.'])
    end
    
    % Create two vectors, one containing estimate types (high or low side)
    % and the other containing reference frequencies.

    % High or low side estimate vector
    estimateType = zeros(1, nTrialsPerBlock);
    % Assign the first half of the values as 1 and the second half as 2
    estimateType(1, 1:(nTrialsPerBlock/2)) = 1;
    estimateType(1, (nTrialsPerBlock/2)+1:nTrialsPerBlock) = 2;

    % Reference frequency vector, which will contain indices of refFreqHz
    refFreqHzIndex = zeros(1, nTrialsPerBlock);

    group = ceil(nTrialsPerBlock / length(refFreqHz)); 
    startIdx = 1;

    % Loop through indices
    for ii = 1:length(refFreqHz)

        % Find the end index for the current group (range of columns)
        endIdx = startIdx + group - 1;
      
        % Assign the current refFreqHz index value to the current group
        refFreqHzIndex(1, startIdx:endIdx) = ii;

        startIdx = endIdx + 1;

    end

    % Generate all possible pairs and combine them into a single matrix
    % of unique pairs
    [ET, RF] = meshgrid(estimateType, refFreqHzIndex);
    pairs = [ET(:), RF(:)];
    pairs = unique(pairs, 'rows', 'stable');

    % Determine the number of times to repeat each unique pair
    pairRepetitions = nTrialsPerBlock / length(pairs);

    % Now create a list with repeated pairs 
    finalPairs = repmat(pairs, pairRepetitions, 1);  

    % Permute the pairs to randomize the order
    permutedPairs = finalPairs(randperm(size(finalPairs, 1)), :);

    % Present nTrials
    for ii = 1:nTrialsPerBlock
        psychObjArray{permutedPairs(ii, 1), permutedPairs(ii, 2)}.presentTrial
    end

    % Report completion of this block
    fprintf('done.\n');

    % Store the psychObjArray entries
    for ss = 1:2
        for rr = 1:length(refFreqHz)
            % Grab the next psychObj
            psychObj = psychObjArray{ss, rr};
            % empty the CombiLEDObj handles and save the psychObj
            psychObj.CombiLEDObjA = [];
            psychObj.CombiLEDObjB = [];
            save(psychObj.filename,'psychObj');
        end
    end

end % block loop

% Clean up
if ~simulateStimuli
    CombiLEDObjA.goDark;
    CombiLEDObjA.serialClose;

    CombiLEDObjB.goDark;
    CombiLEDObjB.serialClose;
end
clear CombiLEDObj

end % function
