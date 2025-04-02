% Object to support nulling of chromatic and achromatic components of
% modulations. A "source" modResult is passed to the routine, as well as a
% "silencing" modResult. The observer is invited to adjust the weight of
% silencing modulation direction that is added or removed from the source
% modulation direction to null a percetual feature.
%
% A typical application would be to pass an L-M "source" modulation and an
% M-cone isolating "silencing" modulation, with the goal of nulling
% a residual luminance component.


classdef PsychFlickerNull < handle

    properties (Constant)
    end

    % Private properties
    properties (GetAccess=private)
    end

    % Calling function can see, but not modify
    properties (SetAccess=private)
        sourceModResult
        silencingModResult
        maxAdjustWeight
        simulateResponse
        simulateStimuli
        stimFreqHz
        stimContrast
        nAdjustmentSteps
        stimWaveform
        asymmetricAdjustFlag
        currTrialIdx = 0;
        trialData
        nTrials 
    end

    % These may be modified after object creation
    properties (SetAccess=public)

        % The display object. This is modifiable so that we can re-load
        % a PsychDetectionThreshold, update this handle, and then continue
        % to collect data
        CombiLEDObj

        % The adjustment weight may be modified to allow larger and smaller
        % refinements of the stimulus appearance
        adjustWeightDelta = 0.01;

        % Verbosity
        verbose = true;
        blockStartTimes = datetime();

        % Assign a filename which is handy for saving and loading
        filename

    end

    methods

        % Constructor
        function obj = PsychFlickerNull(CombiLEDObj,sourceModResult,silencingModResult,varargin)

            % input parser
            p = inputParser; p.KeepUnmatched = false;
            p.addParameter('stimFreqHz',24,@isnumeric);
            p.addParameter('stimContrast',0.1,@isnumeric);
            p.addParameter('nAdjustmentSteps',10,@isnumeric);
            p.addParameter('stimWaveform',2,@isscalar);
            p.addParameter('asymmetricAdjustFlag',false,@islogical);
            p.addParameter('simulateResponse',false,@islogical);
            p.addParameter('simulateStimuli',false,@islogical);
            p.addParameter('verbose',true,@islogical);
            p.addParameter('nTrials',12, @isnumeric);
            p.parse(varargin{:})

            % Place various inputs and options into object properties
            obj.CombiLEDObj = CombiLEDObj;
            obj.sourceModResult = sourceModResult;
            obj.silencingModResult = silencingModResult;
            obj.stimFreqHz = p.Results.stimFreqHz;
            obj.stimContrast = p.Results.stimContrast;   
            obj.nAdjustmentSteps = p.Results.nAdjustmentSteps;
            obj.stimWaveform = p.Results.stimWaveform;              
            obj.asymmetricAdjustFlag = p.Results.asymmetricAdjustFlag;                        
            obj.simulateResponse = p.Results.simulateResponse;
            obj.simulateStimuli = p.Results.simulateStimuli;
            obj.nTrials = p.Results.nTrials;
            obj.verbose = p.Results.verbose;

            % Confirm that the source and silencing modResults have the
            % same background settings
            assert(all( (sourceModResult.settingsBackground - silencingModResult.settingsBackground) == 0));

            % Calculate the largest available silencing direction
            % adjustment that we can appply which is within device gamut
            settingsBackground = sourceModResult.settingsBackground;
            modRoom = min([1-settingsBackground, settingsBackground],[],2);
            sourceDirection = sourceModResult.settingsHigh - sourceModResult.settingsBackground;
            silencingDirection = silencingModResult.settingsHigh - silencingModResult.settingsBackground;
            obj.maxAdjustWeight = min((modRoom - sourceDirection) ./ abs(silencingDirection));

            % Set the adjustWeightDelta to provide 20 divisions from the
            % max
            obj.adjustWeightDelta = obj.maxAdjustWeight / obj.nAdjustmentSteps;

            % Detect incompatible simulate settings
            if obj.simulateStimuli && ~obj.simulateResponse
                fprintf('Forcing simulateResponse to true, as one cannot respond to a simulated stimulus\n')
                obj.simulateResponse = true;
            end

            % Initialize the blockStartTimes field
            obj.blockStartTimes(1) = datetime();
            obj.blockStartTimes(1) = [];

            % Initialize the CombiLED
            obj.initializeDisplay;

        end

        % Required methods
        initializeDisplay(obj)
        modResult = createAdjustedModResult(obj,adjustWeight)
        presentTrial(obj)
        [choice, responseTimeSecs] = getResponse(obj)
    end
end