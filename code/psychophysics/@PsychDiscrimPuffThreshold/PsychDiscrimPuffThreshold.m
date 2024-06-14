% Object to support conducting a 2AFC contrast threshold discrimination
% task, using the log Weibull CFD under the control of Quest+ to select
% stimuli. A nuance of the parameterization is that we allow Quest+ to
% search for the value of the "guess rate", even though by design this rate
% must be 0.5. By providing this bit of flexibility in the parameter space,
% Quest+ tends to explore the lower end of the contrast range a bit more,
% resulting in slightly more accurate estimates of the slope of the
% psychometric function. When we derive the final, maximum likelihood set
% of parameters, we lock the guess rate to 0.5.
%
% The parameters of the psychometric function are:
%                      threshold  Threshold parameter in log units
%                      slope      Slope
%                      guess      Guess rate
%                      lapse      Lapse rate
%

classdef PsychDiscrimPuffThreshold < handle

    properties (Constant)
    end

    % Private properties
    properties (GetAccess=private)
    end

    % Calling function can see, but not modify
    properties (SetAccess=private)
        questData
        simulatePsiParams
        simulateResponse
        simulateStimuli
        giveFeedback
        psiParamsDomainList
        refLogIntensity
        validLogIntesityRange
        logIntensityDiffSet
        stimulusDurSecs = 0.2;
        PostStimDelaySecs = 0.35;
        interStimulusIntervalSecs = 1;
    end

    % These may be modified after object creation
    properties (SetAccess=public)

        % The stimulus object. This is modifiable so that we can re-load
        % a PsychDetectionThreshold, update this handle, and then continue
        % to collect data
        CombiAirObj

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
        function obj = PsychDiscrimPuffThreshold(CombiAirObj,refLogIntensity,varargin)

            % input parser
            p = inputParser; p.KeepUnmatched = false;
            p.addParameter('simulateResponse',false,@islogical);
            p.addParameter('simulateStimuli',false,@islogical);
            p.addParameter('giveFeedback',true,@islogical);
            p.addParameter('validLogIntesityRange',[0,2.8],@isnumeric);
            p.addParameter('logIntensityDiffSet',linspace(0,1,31),@isnumeric);
            p.addParameter('simulatePsiParams',[0.5, 1.5, 0.5, 0.0],@isnumeric);
            p.addParameter('psiParamsDomainList',{...
                linspace(0.01,1,21), ...
                logspace(log10(1),log10(10),21),...
                [0.5],...
                [0]...
                },@isnumeric);
            p.addParameter('verbose',true,@islogical);
            p.parse(varargin{:})

            % Place various inputs and options into object properties
            obj.CombiAirObj = CombiAirObj;
            obj.refLogIntensity = refLogIntensity;
            obj.validLogIntesityRange = p.Results.validLogIntesityRange;
            obj.logIntensityDiffSet = p.Results.logIntensityDiffSet;
            obj.simulateResponse = p.Results.simulateResponse;
            obj.simulateStimuli = p.Results.simulateStimuli;
            obj.giveFeedback = p.Results.giveFeedback;
            obj.simulatePsiParams = p.Results.simulatePsiParams;
            obj.psiParamsDomainList = p.Results.psiParamsDomainList;
            obj.verbose = p.Results.verbose;

            % Detect incompatible simulate settings
            if obj.simulateStimuli && ~obj.simulateResponse
                fprintf('Forcing simulateResponse to true, as one cannot respond to a simulated stimulus\n')
                obj.simulateResponse = true;
            end

            % Initialize the blockStartTimes field
            obj.blockStartTimes(1) = datetime();
            obj.blockStartTimes(1) = [];

            % Initialize Quest+
            obj.initializeQP;

        end

        % Required methds
        initializeQP(obj)
        validResponse = presentTrial(obj)
        [intervalChoice, responseTimeSecs] = getResponse(obj)
        [intervalChoice, responseTimeSecs] = getSimulatedResponse(obj,qpStimParams,testInterval)
        waitUntil(obj,stopTimeMicroSeconds)
        [psiParamsQuest, psiParamsFit, psiParamsCI, fVal] = reportParams(obj,options)
        figHandle = plotOutcome(obj,visible)
        resetSearch(obj)
    end
end