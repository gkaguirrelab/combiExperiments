function runDCPTFlickerDetectionThresh(subjectID,NDlabelC,NDlabelD,testFreqSetHz,varargin)
% Psychometric measurement of contrast detection thresholds using a 
% binocular rig at a set of frequencies for two post-receptoral directions (LMS and L-M).
%
% Examples:
%{
    subjectID = 'TEST';
    NDlabelC = '0';
    NDlabelD = '0';
    testFreqSetHz = [8];
    runDCPTFlickerDetectionThresh(subjectID,NDlabelC,NDlabelD,testFreqSetHz);
%}

% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('dropBoxBaseDir',getpref('combiExperiments','dropboxBaseDir'),@ischar);
p.addParameter('dropBoxSubDir','FLIC_data',@ischar);
p.addParameter('projectName','combiLED',@ischar);
p.addParameter('modDirections',{'LminusM_wide','LightFlux'},@iscell);
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
% CombiLED C
modResultFileC = ...
    fullfile(subjectDir,[modDirections{2} '_ND' NDlabelC '_C_ND' NDlabelD '_D'],'modResult_C.mat');
load(modResultFileC,'modResult');
calC = modResult.meta.cal;

% CombiLED D
modResultFileD = ...
    fullfile(subjectDir,[modDirections{2} '_ND' NDlabelC '_C_ND' NDlabelD '_D'],'modResult_D.mat');
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

    % for now, just light flux
    directionIdx = 2;
    % % Switch back and forth between the modulation directions
    % directionIdx = mod(bb,2)+1;

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
    psychObjArray = cell(length(testFreqSetHz));

    for rr = 1:length(testFreqSetHz)

        % Define the filestem for this psychometric object
        dataDir = fullfile(subjectDir,[modDirections{directionIdx} '_ND' NDlabelC '_C_ND' NDlabelD '_D'],experimentName);
        psychFileStem = [subjectID '_' modDirections{directionIdx} '_' experimentName,'.','x', ...
            '_refFreq-' num2str(testFreqSetHz(rr)) 'Hz' ...
            '_' stimParamLabels{1}];

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
                 testFreqSetHz(rr), ...
                'verbose',verbosePsychObj, ...
                'simulateResponse',simulateResponse,'simulateStimuli',simulateStimuli,...
                'useStaircase', useStaircase, 'randomCombi', randomCombi);
            % Store the filename
            psychObj.filename = filename;
        end

        % Store in the psychObjArray
        psychObjArray{rr} = psychObj;

        % Clear the psychObj
        clear psychObj

    end

    % Initialize the display for one of the psychObj elements. This routine
    % assumes that all of the psychObj elements that will be called during
    % the block use the same modulation, modulation background, temporal
    % profile (i.e., sinusoid), and trial duration.
    psychObjArray{1}.initializeDisplay;

    % Start the block
    fprintf('Press enter to start block %d...',bb);
    input('');

    % Store the block start time
    for rr = 1:length(testFreqSetHz)
        blockStartTime = datetime();
        psychObjArray{rr}.blockStartTimes(psychObjArray{rr}.blockIdx) = blockStartTime;
    end

    % Verify that the number of trials per block is compatible with the
    % number of test frequencies.
    if mod(nTrialsPerBlock, length(testFreqSetHz) * 2) ~= 0
        error(['The number of trials must be even and a ' ...
            'multiple of the number of reference frequencies.'])
    end

    % Randomizing the order that reference frequencies are presented in. 
    % Reference frequency vector, which will contain indices of testFreqSetHz
    testFreqHzIndex = zeros(1, nTrialsPerBlock);

    % Group the trials so each reference frequency is presented an equal
    % number of times
    group = ceil(nTrialsPerBlock / length(testFreqSetHz)); 
    startIdx = 1;

    % Loop through indices
    for ii = 1:length(testFreqSetHz)

        % Find the end index for the current group (range of columns)
        endIdx = startIdx + group - 1;
      
        % Assign the current testFreqSetHz index value to the current group
        testFreqHzIndex(1, startIdx:endIdx) = ii;

        startIdx = endIdx + 1;

    end

    % Now randomize the reference frequency order
    testFreqHzIndex = testFreqHzIndex(randperm(nTrialsPerBlock));

    % Present nTrials
    for ii = 1:nTrialsPerBlock
        psychObjArray{testFreqHzIndex(ii)}.presentTrial();
    end

    % Report completion of this block
    fprintf('done.\n');

    % Store the psychObjArray entries
    for rr = 1:length(testFreqSetHz)
        % Grab the next psychObj
        psychObj = psychObjArray{rr};
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
