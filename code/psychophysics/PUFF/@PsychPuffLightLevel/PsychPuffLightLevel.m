% Object to support recording of eye videos while the subject attempts to
% detect brief "blink" events in a steady light at different intensity
% levels.

classdef PsychPuffLightLevel < handle

    properties (Constant)
    end

    % Private properties
    properties (GetAccess=private)
    end

    % Calling function can see, but not modify
    properties (SetAccess=private)
        cameraCleanupDurSecs = 5.0;
        modResult
        lightPulseDurSecs = 30;
        blinkEventIntervalSecs = 4;
        blinkEventProbability = 0.333;
        blinkResponseIntervalSecs = 1.5;
        trialLabel
        simulateResponse
        simulateStimuli
        trialData
        currTrialIdx = 0;
    end

    % These may be modified after object creation
    properties (SetAccess=public)

        % The object for making infrared recordings of the eyes
        irCameraObj

        % The combiLED object. This is modifiable so that we can re-load
        % the psychometric object, update this handle, and then continue
        % to collect data 
        LightObj

        % Assign a filename which is handy for saving and loading
        filename

        % Verbosity
        verbose = true;

    end

    methods

        % Constructor
        function obj = PsychPuffLightLevel(irCameraObj,LightObj,modResult,varargin)

            % input parser
            p = inputParser; p.KeepUnmatched = false;
            p.addParameter('trialLabel','',@ischar);            
            p.addParameter('simulateResponse',false,@islogical);
            p.addParameter('simulateStimuli',false,@islogical);
            p.addParameter('lightPulseDurSecs',30,@isnumeric);
            p.addParameter('blinkEventIntervalSecs',5,@isnumeric);
            p.addParameter('verbose',true,@islogical);
            p.parse(varargin{:})

            % Place various inputs and options into object properties
            obj.irCameraObj = irCameraObj;            
            obj.LightObj = LightObj;
            obj.modResult = modResult;
            obj.trialLabel = p.Results.trialLabel;
            obj.simulateResponse = p.Results.simulateResponse;
            obj.simulateStimuli = p.Results.simulateStimuli;
            obj.lightPulseDurSecs = p.Results.lightPulseDurSecs;
            obj.blinkEventIntervalSecs = p.Results.blinkEventIntervalSecs;
            obj.verbose = p.Results.verbose;

            % Detect incompatible simulate settings
            if obj.simulateStimuli && ~obj.simulateResponse
                fprintf('Forcing simulateResponse to true, as one cannot respond to a simulated stimulus\n')
                obj.simulateResponse = true;
            end

            % Initialize the CombiLED
            obj.initializeDisplay;

        end

        % Required methds
        initializeDisplay(obj)
        presentTrial(obj,contrast)
        [detected, responseTimeSecs] = blinkEvent(obj);
        waitUntil(obj,stopTimeSeconds)
    end
end