function runDCPT_discrim(subjectID,NDlabel,refFreqHz,varargin)
% Psychometric measurement of discrmination thresholds at a set of
% frequencies for two post-receptoral directions (LMS and L-M).
%
%% NEED HEDAER COMMENTS

% Optional
% targetPhotoContrast       - 2xd vector, where d is the number of modulation
%                               directions to be studied. columns mod dir,
%                               rows are contrast level. Provides the low
%                               and high contrast levels to be studied. The
%                               default values are approximately 5x and 20x
%                               detection thresholds from pilot temporal
%                               contrast sensitivity functions detection
%                               measures. We found thresholds of
%                               approximately 0.005 contrast for L-M and
%                               0.01 contrast for LF at lower temporal
%                               frequencies.

% Examples:
%{
    subjectID = 'HERO_sam';
    NDlabel = '0x5';
    refFreqHz = [3.0000    5.0454    8.4853   14.2705   24.0000];
    runDCPT_discrim(subjectID,NDlabel,refFreqHz);
%}

% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('dropBoxBaseDir',getpref('combiExperiments','dropboxBaseDir'),@ischar);
p.addParameter('dropBoxSubDir','FLIC_data',@ischar);
p.addParameter('projectName','combiLED',@ischar);
p.addParameter('modDirections',{'LminusM_wide','LightFlux'},@iscell);
p.addParameter('targetPhotoContrast',[0.025,0.05; 0.05, 0.3],@isnumeric); 
p.addParameter('stimParamsHi',{linspace(0,5,51),linspace(0,5,51)},@isnumeric);
p.addParameter('stimParamsLow',{linspace(-5,0,51),linspace(-5,0,51)},@isnumeric);
p.addParameter('nTrialsPerBlock',20,@isnumeric);
p.addParameter('nBlocks',10,@isnumeric);
p.addParameter('useStaircase',false,@islogical);
p.addParameter('verboseCombiLED',false,@islogical);
p.addParameter('verbosePsychObj',true,@islogical);
p.addParameter('simulateResponse',false,@islogical);
p.addParameter('simulateStimuli',false,@islogical);
p.addParameter('randomCombi',true,@islogical);
p.addParameter('useKeyboardFlag',false,@islogical);
p.parse(varargin{:})

%  Pull out of the p.Results structure
nTrialsPerBlock = p.Results.nTrialsPerBlock;
nBlocks = p.Results.nBlocks;
useStaircase = p.Results.useStaircase;
modDirections = p.Results.modDirections;
targetPhotoContrast = p.Results.targetPhotoContrast;
verboseCombiLED = p.Results.verboseCombiLED;
verbosePsychObj = p.Results.verbosePsychObj;
simulateResponse = p.Results.simulateResponse;
simulateStimuli = p.Results.simulateStimuli;
randomCombi = p.Results.randomCombi;
useKeyboardFlag = p.Results.useKeyboardFlag;

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
% CombiLED C -- left eyepiece
modResultFileC = ...
    fullfile(subjectDir,[modDirections{1} '_ND' NDlabel],'modResult_C.mat');
load(modResultFileC,'modResult');
calC = modResult.meta.cal;

% CombiLED D -- right eyepiece
modResultFileD = ...
    fullfile(subjectDir,[modDirections{1} '_ND' NDlabel],'modResult_D.mat');
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

% Test that the CombiC and D objects have the correct identifier strings
assert(CombiLEDObjC.identifierString == "A10L31XJ");
assert(CombiLEDObjD.identifierString == "A10L31XZ");

% Provide instructions
if useKeyboardFlag

    fprintf('**********************************\n');
    fprintf('On each of many trials you will be presented with flicker\n');
    fprintf('on the left and right. Your job is to indicate which side\n');
    fprintf('had the faster flickering stimulus by pressing the 1(left) or 2(right) key on the\n');
    fprintf('keyboard. Each block has %d trials in a row after\n',nTrialsPerBlock);
    fprintf('which you may take a brief break. There are a total of %d blocks.\n',nBlocks);
    fprintf('**********************************\n\n');

else

    fprintf('**********************************\n');
    fprintf('On each of many trials you will be presented with flicker\n');
    fprintf('on the left and right. Your job is to indicate which side\n');
    fprintf('had the faster flickering stimulus by pressing the left or right\n');
    fprintf('bumpers on the game pad. Each block has %d trials in a row after\n',nTrialsPerBlock);
    fprintf('which you may take a brief break. There are a total of %d blocks.\n',nBlocks);
    fprintf('**********************************\n\n');

end

% Prepare to loop over blocks
for bb=1:nBlocks

    % Switch back and forth between the modulation directions
    directionIdx = mod(bb,2)+1;

    % Which direction we will use this time
    modResultFileC = ...
        fullfile(subjectDir,[modDirections{directionIdx} '_ND' NDlabel '_shifted'],'modResult_C.mat');

    modResultFileD = ...
        fullfile(subjectDir,[modDirections{directionIdx} '_ND' NDlabel '_shifted'],'modResult_D.mat');

    % Load the previously generated modResult file for this direction
    load(modResultFileC,'modResult');
    modResultC = modResult; clear modResult;

    load(modResultFileD,'modResult');
    modResultD = modResult;

    % Create a directory for the subject
    dataDir = fullfile(subjectDir,[modDirections{directionIdx} '_ND' NDlabel, '_shifted'],experimentName);
    if ~isfolder(dataDir)
        mkdir(dataDir)
    end

    % Assemble the psychObj array, looping over the high and low range of
    % the discrimination function AND the reference frequencies AND the
    % contrast
    psychObjArray = cell(2, length(refFreqHz), size(targetPhotoContrast,1));
    for ss = 1:2 % side, high, low
        for rr = 1:length(refFreqHz)
            for iCont = 1:size(targetPhotoContrast,1)

                % Define the filestem for this psychometric object
                dataDir = fullfile(subjectDir,[modDirections{directionIdx} '_ND' NDlabel, '_shifted'],experimentName);
                psychFileStem = [subjectID '_' modDirections{directionIdx} '_' experimentName ...
                    '_cont-' strrep(num2str(targetPhotoContrast(iCont, directionIdx)),'.','x') ...
                    '_refFreq-' num2str(refFreqHz(rr)) 'Hz' ...
                    '_' stimParamLabels{ss}];

                % Obtain the relevant stimParam values
                stimParamsDomainList = p.Results.(stimParamLabels{ss}){directionIdx};

                % Create or load the psychometric object
                psychObjFilename = fullfile(dataDir,[psychFileStem '.mat']);
                if isfile(psychObjFilename)
                    % Load the object
                    load(psychObjFilename,'psychObj');
                    psychObj.filename = psychObjFilename;
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
                    % Update the keyboard flag
                    psychObj.useKeyboardFlag = useKeyboardFlag;
                    % Update the filename
                    psychObj.filename = psychObjFilename;
                else
                    % Create the object
                    psychObj = PsychDichopticFlickerDiscrim(CombiLEDObjC, CombiLEDObjD, modResultC, modResultD, refFreqHz(rr),...
                        'refPhotoContrast',targetPhotoContrast(iCont,directionIdx),'testPhotoContrast',targetPhotoContrast(iCont,directionIdx),...
                        'stimParamsDomainList',stimParamsDomainList,'verbose',verbosePsychObj, ...
                        'simulateResponse',simulateResponse,'simulateStimuli',simulateStimuli,...
                        'useStaircase', useStaircase, 'randomCombi', randomCombi, ...
                        'useKeyboardFlag', useKeyboardFlag);
                    % Store the filename
                    psychObj.filename = filename;
                end

                % Store in the psychObjArray
                psychObjArray{ss, rr, iCont} = psychObj;

                % Clear the psychObj
                clear psychObj
            end
        end

    end

    % Initialize the display for one of the psychObj elements. This routine
    % assumes that all of the psychObj elements that will be called during
    % the block use the same modulation, modulation background, temporal
    % profile (i.e., sinusoid), and trial duration.
    psychObjArray{1,1,1}.initializeDisplay;

    % Start the block
    if useKeyboardFlag     
        % If using keyboard
        fprintf('Press enter to start block %d...',bb);
        input('');
    else
        % If using gamepad
        fprintf('Press button 1, 2, 3, or 4 to start block %d...',bb);
        while true
            buttonState1 = Gamepad('GetButton', 1, 1);
            buttonState2 = Gamepad('GetButton', 1, 2);
            buttonState3 = Gamepad('GetButton', 1, 3);
            buttonState4 = Gamepad('GetButton', 1, 4);
            if buttonState1 == 1 || buttonState2 == 1 || buttonState3 == 1 || buttonState4 == 1
                break
            end
        end
    end

    % Store the block start time
    for ss = 1:2
        for rr = 1:length(refFreqHz)
            for iCont = 1:size(targetPhotoContrast,1)
                blockStartTime = datetime();
                psychObjArray{ss, rr, iCont}.blockStartTimes(psychObjArray{ss,rr, iCont}.blockIdx) = blockStartTime;
            end
        end
    end

    % Verify that the number of trials per block is compatible with the number
    % of reference frequencies.
    if mod(nTrialsPerBlock, length(refFreqHz) * 2) ~= 0
        error(['The number of trials must be even and a ' ...
            'multiple of the number of reference frequencies and contrast levels.'])
    end

    % Create three vectors, one containing estimate types (high or low
    % side), another for contrast levels, and the other containing
    % reference frequencies.

    % High or low side estimate vector
    estimateType = zeros(1, nTrialsPerBlock);
    
    % Assign the first half of the values as 1 and the second half as 2
    estimateType(1, 1:(nTrialsPerBlock/2)) = 1;
    estimateType(1, (nTrialsPerBlock/2)+1:nTrialsPerBlock) = 2;

    % Reference frequency vector, which will contain indices of refFreqHz
    refFreqHzIndex = zeros(1, nTrialsPerBlock);
    group = ceil(nTrialsPerBlock / length(refFreqHz));

    % Loop through indices
    startIdx = 1;
    for ii = 1:length(refFreqHz)

        % Find the end index for the current group (range of columns)
        endIdx = startIdx + group - 1;

        % Assign the current refFreqHz index value to the current group
        refFreqHzIndex(1, startIdx:endIdx) = ii;

        startIdx = endIdx + 1;

    end

    contIndex = zeros(1, nTrialsPerBlock);
    contrastGroup = nTrialsPerBlock/(size(targetPhotoContrast,1));
    startIdxCont = 1;

     % Loop through indices for contrasts
    for ii = 1:size(targetPhotoContrast,1)

        % Find the end index for the current group (range of columns)
        endIdxCont = startIdxCont + contrastGroup - 1;

        % Assign the current refFreqHz index value to the current group
        contIndex(1, startIdxCont:endIdxCont) = ii;

        startIdxCont = endIdxCont + 1;
    end

    % Generate all possible pairs and combine them into a single matrix
    % of unique pairs
    [ET, RF, CL] = meshgrid(estimateType, refFreqHzIndex, contIndex);
    triplets = [ET(:), RF(:), CL(:)];
    triplets = unique(triplets, 'rows', 'stable');

    % Determine the number of times to repeat each unique triplet
    tripletRepetitions = nTrialsPerBlock / length(triplets);

    % Now create a list with repeated triplets
    finalTriplets = repmat(triplets, tripletRepetitions, 1);

    % Permute the pairs to randomize the order
    permutedPairs = finalTriplets(randperm(size(finalTriplets, 1)), :);

    % Present nTrials
    for ii = 1:nTrialsPerBlock
        psychObjArray{permutedPairs(ii, 1), permutedPairs(ii, 2), permutedPairs(ii, 3)}.presentTrial
    end

    % Report completion of this block
    fprintf('done.\n');

    % Store the psychObjArray entries
    for ss = 1:2
        for rr = 1:length(refFreqHz)
            for iCont = 1:size(targetPhotoContrast,1)
                % Grab the next psychObj
                psychObj = psychObjArray{ss, rr, iCont};
                % empty the CombiLEDObj handles and save the psychObj
                psychObj.CombiLEDObjC = [];
                psychObj.CombiLEDObjD = [];
                % Save the psychObj        
                save(psychObj.filename,'psychObj');
            end
        end
    end
    BlockDone = load('gong.mat');
    if bb<nBlocks
        sound(BlockDone.y, BlockDone.Fs)
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

%tell participant the task is done
ExperimentDone = load('handel');
sound(ExperimentDone.y,ExperimentDone.Fs)

end % function
