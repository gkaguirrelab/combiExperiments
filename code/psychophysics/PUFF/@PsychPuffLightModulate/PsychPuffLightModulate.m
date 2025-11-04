% Object to support the presentation of slow sinusoidal modulations around
% the background of a modulation direction while recording IR video

classdef PsychPuffLightModulate < handle

    properties (Constant)
    end

    % Private properties
    properties (GetAccess=private)
    end

    % Calling function can see, but not modify
    properties (SetAccess=private)
        cameraCleanupDurSecs = 5.0;
        modResult
        simulateStimuli
        simulateResponse
        lightModContrast = 1
        lightModFreqHz = 1/60;
        lightModDurSecs = 60;
        lightModPhase = 0;
        trialLabel
        trialData
        adaptData
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

        % Counter for adapt periods
        adaptIdx = 1;

    end

    methods

        % Constructor
        function obj = PsychPuffLightModulate(irCameraObj,LightObj,modResult,varargin)

            % input parser
            p = inputParser; p.KeepUnmatched = false;
            p.addParameter('trialLabel','',@ischar);            
            p.addParameter('simulateResponse',false,@islogical);
            p.addParameter('simulateStimuli',false,@islogical);
            p.addParameter('lightModContrast',0.5,@isnumeric);
            p.addParameter('lightModFreqHz',1/60,@isnumeric);
            p.addParameter('lightModDurSecs',60,@isnumeric);
            p.addParameter('lightModPhase',0,@isnumeric);
            p.addParameter('verbose',true,@islogical);
            p.parse(varargin{:})

            % Place various inputs and options into object properties
            obj.irCameraObj = irCameraObj;            
            obj.LightObj = LightObj;
            obj.modResult = modResult;
            obj.trialLabel = p.Results.trialLabel;
            obj.simulateResponse = p.Results.simulateResponse;
            obj.simulateStimuli = p.Results.simulateStimuli;
            obj.lightModContrast = p.Results.lightModContrast;
            obj.lightModFreqHz = p.Results.lightModFreqHz;
            obj.lightModDurSecs = p.Results.lightModDurSecs;
            obj.lightModPhase = p.Results.lightModPhase;
            obj.verbose = p.Results.verbose;

            % Detect incompatible simulate settings
            if obj.simulateStimuli && ~obj.simulateResponse
                fprintf('Forcing simulateResponse to true, as one cannot respond to a simulated stimulus\n')
                obj.simulateResponse = true;
            end

        end

        % Required methds
        initializeDisplay(obj)
        recordAdaptPeriod(obj,recordLabel,recordDurSecs)
        presentTrial(obj)
        [intervalChoice, responseTimeSecs] = getResponse(obj);
        waitUntil(obj,stopTimeSeconds)
    end
end