function runDCPTFlickerDetectionThresh(subjectID,NDlabelC,NDlabelD,refFreqHz,testFreqHz,varargin)
% Psychometric measurement of contrast detection thresholds using a 
% binocular rig at a set of frequencies for two post-receptoral directions (LMS and L-M).
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
p.addParameter('targetPhotoreceptorContrast',[0.02,0.05],@isnumeric); % was .075 and .333 but these are too high and cause entoptic spatial pehnomena. Need to find something inbetween:)
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
experimentName = 'DCPT';

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
modResultFileC = ...
    fullfile(subjectDir,[modDirections{1} '_ND' NDlabelC '_C_ND' NDlabelD '_D'],'modResult_C.mat');
load(modResultFileC,'modResult');
calC = modResult.meta.cal;

% CombiLED B
modResultFileD = ...
    fullfile(subjectDir,[modDirections{1} '_ND' NDlabelC '_C_ND' NDlabelD '_D'],'modResult_D.mat');
load(modResultFileD,'modResult');
calD = modResult.meta.cal;

% Set up the CombiLED
if simulateStimuli
    CombiLEDObjC = [];
    CombiLEDObjD = [];
else
    % Open the CombiLED
    CombiLEDObjC = CombiLEDcontrol('verbose',verboseCombiLED);
    CombiLEDObjD = CombiLEDcontrol('verbose',verboseCombiLED);

    % Check the identifierString and swap objects if needed
    if CombiLEDObjC.identifierString == "A10L31XZ" % wrong identifier
        % Swap the objects
        tempObj = CombiLEDObjC;
        CombiLEDObjC = CombiLEDObjD;
        CombiLEDObjD = tempObj;
    end

    % Update the gamma table
    CombiLEDObjC.setGamma(calC.processedData.gammaTable);
    CombiLEDObjD.setGamma(calD.processedData.gammaTable);
end

% Provide instructions
fprintf('**********************************\n');
fprintf('On each of many trials you will be presented with flicker\n');
fprintf('on the left and right. Your job is to indicate which side\n');
fprintf('had the faster flickering stimulus by pressing the 1(left) or 2(right) key on the\n');
fprintf('numeric key pad. Each block has %d trials in a row after\n',nTrialsPerBlock);
fprintf('which you may take a brief break. There are a total of %d blocks.\n',nBlocks);
fprintf('**********************************\n\n');

% Prepare to loop over blocks
for bb=1:nBlocks

    % Switch back and forth between the modulation directions
    directionIdx = mod(bb,2)+1;

    % Which direction we will use this time
    modResultFileC = ...
        fullfile(subjectDir,[modDirections{directionIdx} '_ND' NDlabelC '_C_ND' NDlabelD '_D'],'modResult_C.mat');

    modResultFileD = ...
        fullfile(subjectDir,[modDirections{directionIdx} '_ND' NDlabelC '_C_ND' NDlabelD '_D'],'modResult_D.mat');

    % Load the previously generated modResult file for this direction
    load(modResultFileC,'modResult');
    modResultC = modResult; clear modResult;

    load(modResultFileD,'modResult');
    modResultD = modResult;

    % Create a directory for the subject
    dataDir = fullfile(subjectDir,[modDirections{directionIdx} '_ND' NDlabelC '_C_ND' NDlabelD '_D'],experimentName);
    if ~isfolder(dataDir)
        mkdir(dataDir)
    end

    % Assemble the psychObj array, looping over the high and low range of
    % the discrimination function AND the reference frequencies
    psychObjArray = cell(1, length(refFreqHz));

    for rr = 1:length(refFreqHz)

        % Define the filestem for this psychometric object
        dataDir = fullfile(subjectDir,[modDirections{directionIdx} '_ND' NDlabelC '_C_ND' NDlabelD '_D'],experimentName);
        psychFileStem = [subjectID '_' modDirections{directionIdx} '_' experimentName,'.','x', ...
            '_refFreq-' num2str(refFreqHz(rr)) 'Hz' ...
            '_' stimParamLabels{1}];

        % Obtain the relevant stimParam values
        stimParamsDomainList = p.Results.(stimParamLabels{1}){directionIdx};

        % Create or load the psychometric object
        filename = fullfile(dataDir,[psychFileStem '.mat']);
        if isfile(filename)
            % Load the object
            load(filename,'psychObj');
            % Put in the fresh CombiLEDObjs
            psychObj.CombiLEDObjC = CombiLEDObjC;
            psychObj.CombiLEDObjD = CombiLEDObjD;
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
            psychObj = PsychDichopticFlickerDetect(CombiLEDObjC, CombiLEDObjD, modResultC, modResultD, ...
                 refFreqHz(rr), testFreqHz(rr), ...
                'verbose',verbosePsychObj, ...
                'simulateResponse',simulateResponse,'simulateStimuli',simulateStimuli,...
                'useStaircase', useStaircase, 'randomCombi', randomCombi);
            % Store the filename
            psychObj.filename = filename;
        end

        % Store in the psychObjArray
        psychObjArray{1, rr} = psychObj;

        % Clear the psychObj
        clear psychObj

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
    for rr = 1:length(refFreqHz)
        blockStartTime = datetime();
        psychObjArray{1, rr}.blockStartTimes(psychObjArray{1,rr}.blockIdx) = blockStartTime;
    end

    % Verify that the number of trials per block is compatible with the number
    % of reference frequencies. 
    if mod(nTrialsPerBlock, length(refFreqHz) * 2) ~= 0
        error(['The number of trials must be even and a ' ...
            'multiple of the number of reference frequencies.'])
    end

    % Randomizing the order that reference frequencies are presented in. 
    % Reference frequency vector, which will contain indices of refFreqHz
    refFreqHzIndex = zeros(1, nTrialsPerBlock);

    % Group the trials so each reference frequency is presented an equal
    % number of times
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

    % Now randomize the reference frequency order
    refFreqHzIndex = refFreqHzIndex(randperm(nTrialsPerBlock));

    % Present nTrials
    for ii = 1:nTrialsPerBlock
        psychObjArray{1, refFreqHzIndex(ii)}.presentTrial(refFreqHzIndex(ii)) % pass the current ref/test freq to presentTrial to calculate testContrastAdjusted
    end

    % Report completion of this block
    fprintf('done.\n');

    % Store the psychObjArray entries
    for rr = 1:length(refFreqHz)
        % Grab the next psychObj
        psychObj = psychObjArray{1, rr};
        % empty the CombiLEDObj handles and save the psychObj
        psychObj.CombiLEDObjC = [];
        psychObj.CombiLEDObjD = [];
        save(psychObj.filename,'psychObj');
    end

end % block loop

% Clean up
if ~simulateStimuli
    CombiLEDObjC.goDark;
    CombiLEDObjC.serialClose;

    CombiLEDObjD.goDark;
    CombiLEDObjD.serialClose;
end
clear CombiLEDObj

end % function
