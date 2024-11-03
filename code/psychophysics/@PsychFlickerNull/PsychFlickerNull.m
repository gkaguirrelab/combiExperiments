% Object to support nulling of chromatic and achromatic components of
% modulations. A "source" modResult is passed to the routine, as well as a
% "silencing" modResult. The observer is invited to adjust the weight of
% silencing modulation direction that is added or removed from the source
% modulation direction to null a percetual feature.


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
        simulateResponse
        simulateStimuli
        stimFreqHz
        stimContrast
        asymmetricAdjustFlag
    end

    % These may be modified after object creation
    properties (SetAccess=public)

        % The display object. This is modifiable so that we can re-load
        % a PsychDetectionThreshold, update this handle, and then continue
        % to collect data
        CombiLEDObj

        % Verbosity
        verbose = true;
        blockStartTimes = datetime();

        % We allow this to be modified so we
        % can set it to be brief during object
        % initiation when we clear the responses
        responseDurSecs = 3;

    end

    methods

        % Constructor
        function obj = PsychFlickerNull(CombiLEDObj,sourceModResult,silencingModResult,varargin)

            % input parser
            p = inputParser; p.KeepUnmatched = false;
            p.addParameter('stimFreqHz',30,@isnumeric);
            p.addParameter('stimContrast',0.5,@isnumeric);
            p.addParameter('asymmetricAdjustFlag',false,@islogical);
            p.addParameter('simulateResponse',false,@islogical);
            p.addParameter('simulateStimuli',false,@islogical);
            p.addParameter('verbose',true,@islogical);
            p.parse(varargin{:})

            % Place various inputs and options into object properties
            obj.CombiLEDObj = CombiLEDObj;
            obj.sourceModResult = sourceModResult;
            obj.silencingModResult = silencingModResult;
            obj.stimFreqHz = p.Results.stimFreqHz;
            obj.stimContrast = p.Results.stimContrast;            
            obj.asymmetricAdjustFlag = p.Results.asymmetricAdjustFlag;                        
            obj.simulateResponse = p.Results.simulateResponse;
            obj.simulateStimuli = p.Results.simulateStimuli;
            obj.verbose = p.Results.verbose;

            % Check that there is headroom in the modResult

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
        initializeQP(obj)
        initializeDisplay(obj)
        modResult = returnAdjustedModResult(obj,adjustWeight)
        validResponse = presentTrial(obj)
        [intervalChoice, responseTimeSecs] = getResponse(obj)
        [intervalChoice, responseTimeSecs] = getSimulatedResponse(obj,qpStimParams,testInterval)
        waitUntil(obj,stopTimeMicroSeconds)
        [psiParamsQuest, psiParamsFit, psiParamsCI, fVal] = reportParams(obj,options)
        figHandle = plotOutcome(obj,visible)
        resetSearch(obj)
    end
end