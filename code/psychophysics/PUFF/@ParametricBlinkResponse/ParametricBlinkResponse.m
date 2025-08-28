% Present air puffs of varying intensity to measure a parametric
% blink response function.

classdef ParametricBlinkResponse < handle

    properties (Constant)
    end

    % Private properties
    properties (GetAccess=private)
    end

    % Calling function can see, but not modify
    properties (SetAccess=private)
        maxAllowedPressurePSI = 46;
        maxAllowedRefPSIPerSec = 2.5;
        cameraCleanupDurSecs = 2.5;
        trialData
        simulateStimuli
        puffPSISet
        puffDurSecsSet
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

        % The name that will be used to save ir videos. The trial number
        % within the sequence will be appended to this.
        trialLabelStem = '';

        % Assign a filename which is handy for saving and loading
        filename

        % Verbosity
        verbose = true;

        % Counter for sequences
        sequenceIdx = 1;

    end

    methods

        % Constructor
        function obj = ParametricBlinkResponse(AirPuffObj,irCameraObj,varargin)

            % input parser
            p = inputParser; p.KeepUnmatched = false;
            p.addParameter('puffPSISet',logspace(log10(2.8125),log10(45),5),@isnumeric);
            p.addParameter('puffDurSecsSet',ones(1,5)*0.05,@isnumeric);
            p.addParameter('simulateStimuli',false,@islogical);
            p.addParameter('trialDurSecs',4,@isnumeric);
            p.addParameter('preStimDelayRangeSecs',[1.0,1.5],@isnumeric);
            p.addParameter('verbose',true,@islogical);
            p.parse(varargin{:})

            % Place various inputs and options into object properties
            obj.AirPuffObj = AirPuffObj;
            obj.irCameraObj = irCameraObj;            
            
            obj.puffPSISet = p.Results.puffPSISet;
            obj.puffDurSecsSet = p.Results.puffDurSecsSet;
            obj.trialDurSecs = p.Results.trialDurSecs;
            obj.preStimDelayRangeSecs = p.Results.preStimDelayRangeSecs;
            obj.simulateStimuli = p.Results.simulateStimuli;
            obj.verbose = p.Results.verbose;

        end

        % Required methds
        presentTrialSequence(obj,sequence)
        waitUntil(obj,stopTimeSeconds)
    end
end