% Object to support conducting a 2AFC contrast threshold detection task,
% using the log Weibull CFD under the control of Quest+ to select stimuli.
% A nuance of the parameterization is that we allow Quest+ to search for
% the value of the "guess rate", even though by design this rate must be
% 0.5. By providing this bit of flexibility in the parameter space, Quest+
% tends to explore the lower end of the contrast range a bit more,
% resulting in slightly more accurate estimates of the slope of the
% psychometric function. When we derive the final, maximum likelihood set
% of parameters, we lock the guess rate to 0.5.

classdef PsychDetectFlickerThreshold < handle

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
        randomizePhase = false;
        testFreqHz
        testLogContrastSet
        stimulusDurationSecs = 1;
        interStimulusIntervalSecs = 0.2;
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
        function obj = PsychDetectFlickerThreshold(CombiLEDObj,testFreqHz,varargin)

            % input parser
            p = inputParser; p.KeepUnmatched = false;
            p.addParameter('randomizePhase',true,@islogical);
            p.addParameter('simulateResponse',false,@islogical);
            p.addParameter('simulateStimuli',false,@islogical);
            p.addParameter('giveFeedback',true,@islogical);
            p.addParameter('testLogContrastSet',linspace(-3,-0.3,31),@isnumeric);
            p.addParameter('simulatePsiParams',[-2, 1.5, 0.5, 0.0],@isnumeric);
            p.addParameter('psiParamsDomainList',{...
                linspace(-2.5,-0.3,21), ...
                logspace(log10(1),log10(10),21),...
                [0.5],...
                [0]...
                },@isnumeric);
            p.addParameter('verbose',true,@islogical);
            p.parse(varargin{:})

            % Place various inputs and options into object properties
            obj.CombiLEDObj = CombiLEDObj;
            obj.testFreqHz = testFreqHz;
            obj.testLogContrastSet = p.Results.testLogContrastSet;
            obj.randomizePhase = p.Results.randomizePhase;
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

            % Initialize the CombiLED
            obj.initializeDisplay;

            % There is a roll-off (attenuation) of the amplitude of
            % modulations with frequency. Detect those cases which are outside of our ability to
            % correct
            testContrastSetAdjusted = (10.^obj.testLogContrastSet) ./ ...
                contrastAttentionByFreq(obj.testFreqHz);

            % Check that the adjusted contrast does not exceed unity
            mustBeInRange(testContrastSetAdjusted,0,1);

        end

        % Required methds
        initializeQP(obj)
        initializeDisplay(obj)
        validResponse = presentTrial(obj)
        [intervalChoice, responseTimeSecs] = getResponse(obj)
        [intervalChoice, responseTimeSecs] = getSimulatedResponse(obj,qpStimParams,testInterval)
        waitUntil(obj,stopTimeMicroSeconds)
        [psiParamsQuest, psiParamsFit, psiParamsCI, fVal] = reportParams(obj,options)
        figHandle = plotOutcome(obj,visible)
        resetSearch(obj)
    end
end