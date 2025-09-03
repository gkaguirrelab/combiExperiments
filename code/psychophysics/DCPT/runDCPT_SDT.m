function runDCPT_SDT(subjectID,NDlabel,varargin)
% Collect a session of dichoptic flicker discrimination data
%
% Syntax:
%   runDCPT_SDT(subjectID,NDlabel)
%
% Description:
%   This function organizes the collection of data using the
%   @PsychDichopticFlickerSDT psychometric object.
%
%   This routine connects to the CombiLED stimulus devices, creates and
%   subsequently loads the psychometric objects, and presents trials.
%   Trials are organized into blocks. A given block presents each of
%   several reference frequencies crossed with one or more reference
%   contrasts. Blocks alternate between different photoreceptor directions.
%
% Inputs:
%   subjectID             - Char vector or string. The ID of the subject.
%   NDlabel               - Char vector or string. The ND filter used to
%                           adjust the light level of the stimulus
%
% Optional key/value pairs:
%  'modDirections'        - Cell array of char vectors. The names of the
%                           modulation directions to study.
%  'refFreqHz'            - Vector. The reference frequencies to study.
%                           Typically, this is a log spaced set.
%  'targetPhotoContrast'  - 2xd vector, where d is the number of modulation
%                           directions to be studied. columns mod dir, rows
%                           are contrast level. Provides the low and high
%                           contrast levels to be studied. The default
%                           values are approximately 10x and 30x detection
%                           thresholds from pilot temporal contrast
%                           sensitivity functions detection measures. We
%                           found thresholds of approximately 0.005
%                           contrast for L-M and 0.01 contrast for LF at
%                           lower temporal frequencies. This seemed too
%                           high fo L-M, so we used 5x and 15x instead.
%
% Outputs:
%   none
%
% Examples:
%{
    subjectID = 'FLIC_0015';
    NDlabel = '3x0';
    runDCPT_SDT(subjectID,NDlabel,'simulateMode',false);
%}

% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('modDirections',{'LightFlux'},@iscell);
p.addParameter('refFreqHz',logspace(log10(10),log10(30),5),@isnumeric);
p.addParameter('targetPhotoContrast',[0.10; 0.30],@isnumeric);
p.addParameter('combiLEDLabels',{'C','D'},@iscell);
p.addParameter('combiLEDIDs',{"A10L31XJ","A10L31XZ"},@iscell);
p.addParameter('combiClockAdjust',[1.0006,0.9992],@isnumeric);
p.addParameter('dropBoxBaseDir',getpref('combiExperiments','dropboxBaseDir'),@ischar);
p.addParameter('dropBoxSubDir','FLIC_data',@ischar);
p.addParameter('projectName','combiLED',@ischar);
p.addParameter('nTrialsPerBlock',20,@isnumeric);
p.addParameter('nBlocks',28,@isnumeric);
p.addParameter('verboseCombiLED',false,@islogical);
p.addParameter('verbosePsychObj',true,@islogical);
p.addParameter('simulateMode',false,@islogical);
p.addParameter('collectEOGFlag',true,@islogical);
p.addParameter('demoModeFlag',false,@islogical);
p.addParameter('useKeyboardFlag',false,@islogical);
p.parse(varargin{:})

%  Pull out some variablse from the p.Results structure
modDirections = p.Results.modDirections;
refFreqHz = p.Results.refFreqHz;
targetPhotoContrast = p.Results.targetPhotoContrast;
combiLEDLabels = p.Results.combiLEDLabels;
combiLEDIDs = p.Results.combiLEDIDs;
nTrialsPerBlock = p.Results.nTrialsPerBlock;
nBlocks = p.Results.nBlocks;
verboseCombiLED = p.Results.verboseCombiLED;
verbosePsychObj = p.Results.verbosePsychObj;
simulateMode = p.Results.simulateMode;
collectEOGFlag = p.Results.collectEOGFlag;
demoModeFlag = p.Results.demoModeFlag;
useKeyboardFlag = p.Results.useKeyboardFlag;
combiClockAdjust = p.Results.combiClockAdjust;

% Set our experimentName
experimentName = 'DCPT_SDT';

% Set the labels for the high and low stimulus ranges
stimParamSide = {'hi','low'};

% Define some basic trial type quantities
nSides = 2;
nFreqs = length(refFreqHz);
nContrasts = size(targetPhotoContrast,1);
nRanges = length(stimParamSide);
nDirections = length(modDirections);

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
for side = 1:nSides
    modResultFile{side} = ...
        fullfile(subjectDir,[modDirections{1} '_ND' NDlabel '_shifted'],['modResult_' combiLEDLabels{side} '.mat']);
    load(modResultFile{side},'modResult');
    cal{side} = modResult.meta.cal;
end

% Set up the CombiLED
if simulateMode
    CombiLEDObjArr = {[],[]};
    EOGControl = [];
else
    % Open the CombiLED
    for side = 1:nSides
        CombiLEDObjArr{side} = CombiLEDcontrol('verbose',verboseCombiLED);
    end

    % Check the identifierString and swap objects if needed
    if CombiLEDObjArr{1}.identifierString ~= combiLEDIDs{1} % wrong identifier
        % Swap the objects
        tempObj = CombiLEDObjArr{1};
        CombiLEDObjArr{1} = CombiLEDObjArr{2};
        CombiLEDObjArr{2} = tempObj;
        clear tempObj
    end

    % Test that the CombiLED objects now have the correct identifier
    % strings, and update the gamma table
    for side = 1:nSides
        assert(CombiLEDObjArr{side}.identifierString == combiLEDIDs{side});
        CombiLEDObjArr{side}.setGamma(cal{side}.processedData.gammaTable);
        CombiLEDObjArr{side}.setClockAdjustFactor(combiClockAdjust(side));
    end

    % Open the connection to the LabJack
    if collectEOGFlag
        EOGControl = BiopackControl('');
        fprintf('------Collecting EOG Data------\n')
    else
        EOGControl = [];
    end
end


% Provide instructions
if useKeyboardFlag

    fprintf('**********************************\n');
    fprintf('On each of many trials you will be presented with flickering lights\n');
    fprintf('on the left and right.\n');
    fprintf('Your job is to indicate if the pair matches in speed or not.\n');
    fprintf('If the pair is the same, press the 1 key.\n');
    fprintf('If the pair is different, press the 2 key.\n');
    fprintf('Each block has %d trials in a row after\n',nTrialsPerBlock);
    fprintf('which you may take a brief break. There are a total of %d blocks.\n',nBlocks);
    fprintf('**********************************\n\n');

else

    fprintf('**********************************\n');
    fprintf('On each of many trials you will be presented with flickering lights\n');
    fprintf('on the left and right.\n');
    fprintf('Your job is to indicate if the pair matches in speed or not.\n');
    fprintf('If the pair is the same, press one of the top bumpers.\n');
    fprintf('If the pair is different, press one of the bottom bumpers.\n');
    fprintf('Each block has %d trials in a row after\n',nTrialsPerBlock);
    fprintf('which you may take a brief break. There are a total of %d blocks.\n',nBlocks);
    fprintf('**********************************\n\n');

end


%% Initialize the psychObjArray
% Assemble the psychObj array, looping over the high and low range of
% the discrimination function AND the reference frequencies AND the
% contrast
psychObjArray = cell(nDirections,nRanges,nFreqs,nContrasts);

% Loop over directions
for directionIdx = 1:nDirections

    % Load the mod results for this direction for the two combiLEDs
    for side = 1:nSides
        modResultFile{side} = ...
            fullfile(subjectDir,[modDirections{directionIdx} '_ND' NDlabel '_shifted'],['modResult_' combiLEDLabels{side} '.mat']);
        load(modResultFile{side},'modResult');
        modResultArr{side} = modResult;
        clear modResult
    end

    % Create a directory for the subject
    dataDir = fullfile(subjectDir,[modDirections{directionIdx} '_ND' NDlabel, '_shifted'],experimentName);
    if ~isfolder(dataDir)
        mkdir(dataDir)
    end

    % Loop over range, freq, and contrast (within a direction)
    for rangeIdx = 1:nRanges
        for freqIdx = 1:nFreqs
            for contrastIdx = 1:nContrasts

                % Define the filestem for this psychometric object
                dataDir = fullfile(subjectDir,[modDirections{directionIdx} '_ND' NDlabel, '_shifted'],experimentName);
                psychFileStem = [subjectID '_' modDirections{directionIdx} '_' experimentName ...
                    '_cont-' strrep(num2str(targetPhotoContrast(contrastIdx, directionIdx)),'.','x') ...
                    '_refFreq-' num2str(refFreqHz(freqIdx)) 'Hz' ...
                    '_' stimParamSide{rangeIdx}];

                % Create or load the psychometric object
                psychObjFilename = fullfile(dataDir,[psychFileStem '.mat']);
                if isfile(psychObjFilename)
                    % Load the object
                    load(psychObjFilename,'psychObj');
                    % Handle the possibility that the psychObj file has
                    % been moved
                    if ~strcmp(psychObj.filename, psychObjFilename) % file name is different from what is in the object
                        warning('File name stored in psychObj does not match generated filename. Overwriting stored filename to match.')
                        % Update the path to the file in case this has changed
                        psychObj.filename = psychObjFilename;
                    end
                    % Put in the fresh CombiLEDObjs
                    psychObj.CombiLEDObjArr = CombiLEDObjArr;
                    % Put in the fresh EOGControl
                    psychObj.EOGControl = EOGControl;
                    % Increment blockIdx
                    psychObj.blockIdx = psychObj.blockIdx+1;
                    psychObj.blockStartTimes(psychObj.blockIdx) = datetime();
                    % Update the simulateMode in case this has changed
                    psychObj.simulateMode = simulateMode;
                    % Update the keyboard flag
                    psychObj.useKeyboardFlag = useKeyboardFlag;
                else
                    % Create the object
                    psychObj = PsychDichopticFlickerSDT(...
                        CombiLEDObjArr, modResultArr, EOGControl, refFreqHz(freqIdx),...
                        'refPhotoContrast',targetPhotoContrast(contrastIdx,directionIdx),...
                        'testPhotoContrast',targetPhotoContrast(contrastIdx,directionIdx),...
                        'simulateMode',simulateMode,...
                        'stimParamSide',stimParamSide{rangeIdx},...
                        'verbose',verbosePsychObj, ...
                        'useKeyboardFlag',useKeyboardFlag);
                    % Store the filename
                    psychObj.filename = psychObjFilename;

                end

                % Store in the psychObjArray
                psychObjArray{directionIdx, rangeIdx, freqIdx, contrastIdx} = psychObj;

                % Clear the psychObj
                clear psychObj
            end
        end
    end
end


%% Present trials

% Assert that the number of blocks is an integer multiple of the number of
% frequencies and mod directions
assert(mod(nBlocks,nFreqs*nDirections)==0);

% Create a random order of the reference frequencies to examine across
% blocks
nReps = nBlocks / (nFreqs*nDirections);
tuples = zeros(nFreqs*nDirections,2);
[a,b] = ndgrid(1:nDirections,1:nFreqs);
tuples(:,1) = a(:); tuples(:,2) = b(:);
tuples = repmat(tuples,nReps,1);
directionFrequencyTuples = tuples(randperm(nBlocks),:);

% Prepare to loop over blocks
for bb=1:nBlocks

    % Get the modulation direction
    directionIdx = directionFrequencyTuples(bb,1);

    % Get this freqIdx
    freqIdx = directionFrequencyTuples(bb,2);

    % Start the block
    if ~simulateMode
        if useKeyboardFlag
            % If using keyboard
            fprintf('Press enter to start block %d...',bb);
            input('');
        else
            fprintf('Press button 1, 2, 3, or 4 to start block %d...',bb);
            getGamepadResponse(inf,[1 2 3 4]);
        end
    end

    % Assert that we have a sufficient number of trials per block to
    % present every stimulus type an equal and integer number of times
    assert(mod(nTrialsPerBlock,nRanges*nContrasts)==0);

    % Create a random ordering of ranges (high and low) and contrasts (hi
    % or low).
    nReps = nTrialsPerBlock / (nRanges*nContrasts);
    tuples = zeros(nRanges*nContrasts,2);
    [a,b] = ndgrid(1:nRanges,1:nContrasts);
    tuples(:,1) = a(:); tuples(:,2) = b(:);
    tuples = repmat(tuples,nReps,1);
    rangeContrastTuples = tuples(randperm(nTrialsPerBlock),:);

    % Store the block start time and refresh the combiLED and EOG objects
    for rangeIdx = 1:nRanges
        for contrastIdx = 1:nContrasts
            blockStartTime = datetime();
            psychObjArray{directionIdx, rangeIdx, freqIdx, contrastIdx}.blockStartTimes(psychObjArray{directionIdx,rangeIdx,freqIdx, contrastIdx}.blockIdx) = blockStartTime;
            psychObjArray{directionIdx, rangeIdx, freqIdx, contrastIdx}.CombiLEDObjArr = CombiLEDObjArr;
            psychObjArray{directionIdx, rangeIdx, freqIdx, contrastIdx}.EOGControl = EOGControl;
        end
    end

    % Initialize the display for one of the psychObj elements. This routine
    % assumes that all of the psychObj elements that will be called during
    % the block use the same modulation, modulation background, temporal
    % profile (i.e., sinusoid), and trial duration.
    psychObjArray{directionIdx,rangeContrastTuples(1,1),freqIdx,rangeContrastTuples(1,2)}.initializeDisplay;

    % If we are in demo mode, create a set of 0 and ~4 dB testParam values
    % to use
    if demoModeFlag        
        demoTestParams = zeros(1,nTrialsPerBlock);
        demoTestParams(1:floor(nTrialsPerBlock/2)) = 4.3690;
        % demoTestParams(1:floor(nTrialsPerBlock/2)) = 5;
        demoTestParams = demoTestParams(randperm(nTrialsPerBlock));
    end

    % Present nTrials
    for ii = 1:nTrialsPerBlock
        % Determine if we are in data collection or demo mode
        if demoModeFlag
            % Use the previously calculated 0 dB and large dB stimulus
            % values
            psychObjArray{...
                directionIdx,...
                rangeContrastTuples(ii,1),...
                freqIdx,...
                rangeContrastTuples(ii,2)}.presentTrial(demoTestParams(ii))
        else
            % Call for a regular trial
            psychObjArray{...
                directionIdx,...
                rangeContrastTuples(ii,1),...
                freqIdx,...
                rangeContrastTuples(ii,2)}.presentTrial
        end
    end

    % Report completion of this block
    fprintf('done.\n');

    % Store the psychObjArray entries
    for rangeIdx = 1:nRanges
        for contrastIdx = 1:nContrasts
            % Grab the next psychObj
            psychObj = psychObjArray{directionIdx, rangeIdx, freqIdx, contrastIdx};
            % empty the CombiLEDObj and EOGControl handles and save the psychObj
           psychObj.CombiLEDObjArr = {};
           psychObj.EOGControl = {};
            % Save the psychObj
            save(psychObj.filename,'psychObj');
        end
    end

    % Make a sound for the end of the block
    BlockDone.fs = 8000;              % Sampling frequency (Hz)
    duration = 0.25;         % Duration (seconds)
    freq = 600;            % Tone frequency (Hz)
    freq2 = 1200;
    t = 0:1/BlockDone.fs:duration;    % Time vector
    BlockDone.y = sin(2*pi*freq*t);   % Generate sine wave
    BlockDone.y2 = sin(2*pi*freq2*t);

    if bb<nBlocks
        sound(BlockDone.y, BlockDone.fs);           % Play the sound
        pause (0.26);
        sound(BlockDone.y2, BlockDone.fs);           % Play the sound
    end

end % block loop

% Clean up
if ~simulateMode
    for side = 1:nSides
        CombiLEDObjArr{side}.goDark;
        CombiLEDObjArr{side}.serialClose;
    end
    if collectEOGFlag
        EOGControl.labjackOBJ.shutdown();
    end
end
clear CombiLEDObjArr
clear EOGControl

% Tell participant the task is done
sound(BlockDone.y, BlockDone.fs);           % Play the sound
pause (0.26);
sound(BlockDone.y2, BlockDone.fs);           % Play the sound

end % function
