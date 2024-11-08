% Object to support conducting a 2AFC air puff discrimination task,
% using QUEST+ to select stimuli in an effort to estimate the sigma (slope)
% of a cumulative normal Gaussian. The search is also asked to estimate the
% mu (mean) of the cumulative normal, which prompts QUEST+ to explore both
% above and below the reference stimulus. In fitting and reporting the
% results we lock the mu to 0, which corresponds to being 50% accurate when
% there is no physical difference between the stimuli.

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
        staircaseRule
        stimParamsDomainList
        psiParamsDomainList
        refPuffPSI
        stimulusDurationSecs = 0.5;
        interStimulusIntervalSecs = 1;
    end

    % These may be modified after object creation
    properties (SetAccess=public)

        % The display object. This is modifiable so that we can re-load
        % the psychometric object, update this handle, and then continue
        % to collect data
        CombiAirObj

        % Can switch between using a staircase and QUEST+ to select the
        % next trial
        useStaircase

        % Assign a filename which is handy for saving and loading
        filename

        % Verbosity
        verbose = true;
        blockIdx = 1;
        blockStartTimes = datetime();

    end

    methods

        % Constructor
        function obj = PsychDiscrimPuffThreshold(CombiAirObj,refPuffPSI,varargin)

            % input parser
            p = inputParser; p.KeepUnmatched = false;
            p.addParameter('simulateResponse',false,@islogical);
            p.addParameter('simulateStimuli',false,@islogical);
            p.addParameter('giveFeedback',true,@islogical);
            p.addParameter('useStaircase',true,@islogical);            
            p.addParameter('staircaseRule',[1,3],@isnumeric);
            p.addParameter('simulatePsiParams',[0,0.3],@isnumeric);
            p.addParameter('stimParamsDomainList',linspace(0,1,51),@isnumeric);
            p.addParameter('psiParamsDomainList',...
                {linspace(0,0,1),linspace(0,2,51)},@isnumeric);
            p.addParameter('verbose',true,@islogical);
            p.parse(varargin{:})

            % Place various inputs and options into object properties
            obj.CombiAirObj = CombiAirObj;
            obj.refPuffPSI = refPuffPSI;
            obj.simulateResponse = p.Results.simulateResponse;
            obj.simulateStimuli = p.Results.simulateStimuli;
            obj.giveFeedback = p.Results.giveFeedback;
            obj.useStaircase = p.Results.useStaircase;
            obj.staircaseRule = p.Results.staircaseRule;
            obj.simulatePsiParams = p.Results.simulatePsiParams;
            obj.stimParamsDomainList = p.Results.stimParamsDomainList;
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

            % Initialize the CombiAir
            obj.initializeDisplay;

        end

        % Required methds
        initializeQP(obj)
        initializeDisplay(obj)
        presentTrial(obj)
        stimParam = staircase(obj,currTrialIdx);
        [intervalChoice, responseTimeSecs] = getSimulatedResponse(obj,qpStimParams,testInterval)
        waitUntil(obj,stopTimeSeconds)
        [psiParamsQuest, psiParamsFit, psiParamsCI, fVal] = reportParams(obj,options)
        figHandle = plotOutcome(obj,visible)
        resetSearch(obj)
    end
end