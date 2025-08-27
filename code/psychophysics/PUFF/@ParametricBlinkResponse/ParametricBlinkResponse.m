% Present air puffs of varying intensity to measure a parametric
% blink response function. A single call to "presentTrialBlock" results in
% a total of 26 air puffs, requiring roughly 90 seconds to collect.

classdef ParametricBlinkResponse < handle

    properties (Constant)
    end

    % Private properties
    properties (GetAccess=private)
    end

    % Calling function can see, but not modify
    properties (SetAccess=private)
        maxAllowedPressurePSI = 45;
        maxAllowedRefPSIPerSec = 1;
        currTrialIdx = 1;
        trialData
        videoDataPath
        simulateStimuli
        trialDurSecs
        preStimDelayRangeSecs
    end

    % These may be modified after object creation
    properties (SetAccess=public)

        % The air puff object. This is modifiable so that we can re-load
        % the psychometric object, update this handle, and then continue
        % to collect data
        AirPuffObj

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
        blockIdx = 1;
        blockStartTimes = datetime();

    end

    methods

        % Constructor
        function obj = ParametricBlinkResponse(videoDataPath,AirPuffObj,irCameraObj,LightObj,varargin)

            % input parser
            p = inputParser; p.KeepUnmatched = false;
            p.addParameter('simulateStimuli',false,@islogical);
            p.addParameter('trialDurSecs',3,@isnumeric);
            p.addParameter('preStimDelayRangeSecs',[0.5,1.5],@isnumeric);
            p.addParameter('verbose',true,@islogical);
            p.parse(varargin{:})

            % Place various inputs and options into object properties
            obj.videoDataPath = videoDataPath;
            obj.AirPuffObj = AirPuffObj;
            obj.irCameraObj = irCameraObj;            
            obj.LightObj = LightObj;
            
            obj.trialDurSecs = p.Results.trialDurSecs;
            obj.preStimDelayRangeSecs = p.Results.preStimDelayRangeSecs;
            obj.simulateStimuli = p.Results.simulateStimuli;
            obj.verbose = p.Results.verbose;

            % Initialize the blockStartTimes field
            obj.blockStartTimes(1) = datetime();
            obj.blockStartTimes(1) = [];

        end

        % Required methds
        presentTrialSequence(obj,trialLabel,puffPSI,puffDurSecs)
        waitUntil(obj,stopTimeSeconds)
    end
end