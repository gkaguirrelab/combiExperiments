function runDelayedMatchToFreq(subjectID,NDlabel,varargin)
% Psychometric measurement of accuracy and bias in reproduction of the
% frequency of a flickering stimulus after a delay. The code manages a
% series of files that store the data from the experiment. As configured,
% each testing "session" has 20 trials and is about 4 minutes in duration.
%
% Examples:
%{
    subjectID = 'DEMO_001';
    modDirection = 'LightFlux';
    testContrast = 0.8;
    load(fullfile(getpref('combiLEDToolbox','CalDataFolder'),'CombiLED-B_shortLLG_irFilter_classicEyePiece_ND0.mat'),'cals');
    cal = cals{end};
    runDelayedMatchExperiment(subjectID,modDirection,testContrast,'cal',cal);
%}

% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('dropBoxBaseDir',getpref('combiExperiments','dropboxBaseDir'),@ischar);
p.addParameter('dropBoxSubDir','FLIC_data',@ischar);
p.addParameter('projectName','combiLED',@ischar);
p.addParameter('modDirections',{'LminusM_wide','LightFlux'},@iscell);
p.addParameter('targetPhotoreceptorContrast',[0.075,0.333],@isnumeric);
p.addParameter('refFreqRangeHz',[1 32],@isnumeric);
p.addParameter('testRangeDecibels',7,@isnumeric);
p.addParameter('goodJobCriterionDb',1.5,@isnumeric);
p.addParameter('nTrialsPerBlock',20,@isnumeric);
p.addParameter('nBlocks',10,@isnumeric);
p.addParameter('verboseCombiLED',false,@islogical);
p.addParameter('verbosePsychObj',false,@islogical);
p.addParameter('updateFigures',false,@islogical);
p.parse(varargin{:})

%  Pull out of the p.Results structure
refFreqRangeHz = p.Results.refFreqRangeHz;
nTrialsPerBlock = p.Results.nTrialsPerBlock;
nBlocks = p.Results.nBlocks;
modDirections = p.Results.modDirections;
targetPhotoreceptorContrast = p.Results.targetPhotoreceptorContrast;
testRangeDecibels = p.Results.testRangeDecibels;
goodJobCriterionDb = p.Results.goodJobCriterionDb;
verboseCombiLED = p.Results.verboseCombiLED;
verbosePsychObj = p.Results.verbosePsychObj;
updateFigures = p.Results.updateFigures;

% Set our experimentName
experimentName = 'DMTF';

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
fprintf('On each of many trials you will be presented with 2 seconds of flicker.\n');
fprintf('After a delay you will again see a flickering light. Your job is to\n');
fprintf('use the left and right arrow keys to adjust the second flickering\n');
fprintf('light so that it looks the same as the first flicker. When you have\n');
fprintf('made the best match that you can, press the down arrow (or space bar)\n');
fprintf('to record your response and move to the next trial. Each block has\n');
fprintf('%d trials in a row after which you may take a brief break.\n',nTrialsPerBlock);
fprintf('There are a total of %d blocks in this session.\n',nBlocks);
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

    % Define the filestem for this psychometric object
    dataDir = fullfile(subjectDir,[modDirections{directionIdx} '_ND' NDlabel],experimentName);
    psychFileStem = [subjectID '_' modDirections{directionIdx} '_' experimentName ...
        '_' strrep(num2str(targetPhotoreceptorContrast(directionIdx)),'.','x')];

    % Calculate the testContrast
    maxPhotoreceptorContrast = mean(abs(modResult.contrastReceptorsBipolar(modResult.meta.whichReceptorsToTarget)));
    testContrast = targetPhotoreceptorContrast(directionIdx) / maxPhotoreceptorContrast;

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
        psychObj = PsychDelayedMatchToFreq(CombiLEDObj,modResult,refFreqRangeHz,testContrast,...
            'verbose',verbosePsychObj,'testRangeDecibels',testRangeDecibels,...
            'goodJobCriterionDb',goodJobCriterionDb);
    end

    % Start the block
    fprintf('Press enter to start block %d...',bb);
    input('');

    % Store the block start time
    psychObj.blockStartTimes(psychObj.blockIdx) = datetime();

    % Present nTrials.
    for ii = 1:nTrialsPerBlock
        psychObj.presentTrial
    end

    % Report completion of this block
    fprintf('done.\n');

    % empty the CombiLEDObj handle and save the psychObj
    psychObj.CombiLEDObj = [];
    save(filename,'psychObj');

end % block loop

end % function
