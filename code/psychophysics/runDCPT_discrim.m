function runDCPT_discrim(subjectID,NDlabel,refFreqHz,varargin)
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
p.addParameter('targetPhotoreceptorContrast',[0.025,0.01; 0.05, 0.2; 0.1, 0.4],@isnumeric); % approximately 5x, 10x, and 20 x detection threshold for low sensitivity frequencies. columns mod dir, rows are contrast level
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
p.addParameter('useKeyboardFlag',false,@islogical);
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
% CombiLED A
modResultFileC = ...
    fullfile(subjectDir,[modDirections{1} '_ND' NDlabel],'modResult_C.mat');
load(modResultFileC,'modResult');
calA = modResult.meta.cal;

% CombiLED B
modResultFileD = ...
    fullfile(subjectDir,[modDirections{1} '_ND' NDlabel],'modResult_D.mat');
load(modResultFileD,'modResult');
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
        fullfile(subjectDir,[modDirections{directionIdx} '_ND' NDlabel],'modResult_C.mat');

    modResultFileD = ...
        fullfile(subjectDir,[modDirections{directionIdx} '_ND' NDlabel],'modResult_D.mat');

    % Load the previously generated modResult file for this direction
    load(modResultFileC,'modResult');
    modResultC = modResult; clear modResult;

    load(modResultFileD,'modResult');
    modResultD = modResult;

    % Create a directory for the subject
    dataDir = fullfile(subjectDir,[modDirections{directionIdx} '_ND' NDlabel],experimentName);
    if ~isfolder(dataDir)
        mkdir(dataDir)
    end

    % Assemble the psychObj array, looping over the high and low range of
    % the discrimination function AND the reference frequencies AND the
    % contrast
    psychObjArray = cell(2, length(refFreqHz));
    for ss = 1:2
        for rr = 1:length(refFreqHz)
            for iCont = size(targetPhotoreceptorContrast,2)

                % Define the filestem for this psychometric object
                dataDir = fullfile(subjectDir,[modDirections{directionIdx} '_ND' NDlabel],experimentName);
                psychFileStem = [subjectID '_' modDirections{directionIdx} '_' experimentName ...
                    '_' strrep(num2str(targetPhotoreceptorContrast(directionIdx, iCont)),'.','x') ...
                    '_refFreq-' num2str(refFreqHz(rr)) 'Hz' ...
                    '_' stimParamLabels{ss}];

                % Calculate the testContrast
                %% NOTE THAT WE WILL NEED TO OBTAIN SEPARATE A AND B TEST
                % contrast levels, as the photoreceptor contrast can / will
                % differ between the A and B combiLED modResults. For now, just
                % doing the calculation for modResultA.
                %%ALSO need to do all the contrast levels.
                maxPhotoreceptorContrast = mean(abs(modResultC.contrastReceptorsBipolar(modResultC.meta.whichReceptorsToTarget)));
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
                    % Update the keyboard flag
                    psychObj.useKeyboardFlag = useKeyboardFlag;
                else
                    % Create the object
                    psychObj = PsychDichopticFlickerDiscrim(CombiLEDObjA, CombiLEDObjB, modResultC, modResultD, refFreqHz(rr),...
                        'refContrast',testContrast,'testContrast',testContrast,...
                        'stimParamsDomainList',stimParamsDomainList,'verbose',verbosePsychObj, ...
                        'simulateResponse',simulateResponse,'simulateStimuli',simulateStimuli,...
                        'useStaircase', useStaircase, 'randomCombi', randomCombi, ...
                        'useKeyboardFlag', useKeyboardFlag);
                    % Store the filename
                    psychObj.filename = filename;
                end

                % Store in the psychObjArray
                psychObjArray{ss, rr} = psychObj;

                % Clear the psychObj
                clear psychObj
            end
        end

    end

    % Initialize the display for one of the psychObj elements. This routine
    % assumes that all of the psychObj elements that will be called during
    % the block use the same modulation, modulation background, temporal
    % profile (i.e., sinusoid), and trial duration.
    psychObjArray{1,1}.initializeDisplay;

    if useKeyboardFlag     % If using keyboard

        % Start the block
        fprintf('Press enter to start block %d...',bb);

        input('');

    else

        % Start the block
        fprintf('Press button 1, 2, 3, or 4 to start block %d...',bb);

        while true  % If using gamepad
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
