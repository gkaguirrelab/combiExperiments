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
        adjustedModResult
        simulateResponse
        simulateStimuli
        stimFreqHz
        stimContrast
        stimWaveform
        asymmetricAdjustFlag
        adjustWeight
        currTrialIdx = 0;
        responseDurSecs = 3;
        lastResponse
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

    end

    methods

        % Constructor
        function obj = PsychFlickerNull(CombiLEDObj,sourceModResult,silencingModResult,varargin)

            % input parser
            p = inputParser; p.KeepUnmatched = false;
            p.addParameter('stimFreqHz',30,@isnumeric);
            p.addParameter('stimContrast',0.5,@isnumeric);
            p.addParameter('stimWaveform',2,@isscalar);
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
            obj.stimWaveform = p.Results.stimWaveform;              
            obj.asymmetricAdjustFlag = p.Results.asymmetricAdjustFlag;                        
            obj.simulateResponse = p.Results.simulateResponse;
            obj.simulateStimuli = p.Results.simulateStimuli;
            obj.verbose = p.Results.verbose;

            % Set the adjustment weight to zero and define the starting
            % point of the adjustedModResult
            obj.adjustWeight = 0;
            obj.adjustedModResult = sourceModResult;

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
        createAdjustedModResult(obj)
        presentTrial(obj)
        [choice, responseTimeSecs] = getResponse(obj)
    end
end