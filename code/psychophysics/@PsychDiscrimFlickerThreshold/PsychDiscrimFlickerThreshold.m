% Object to support conducting a 2AFC flicker discrimination task,
% using QUEST+ to select stimuli in an effort to estimate the sigma (slope)
% of a cumulative normal Gaussian. The search is also asked to estimate the
% mu (mean) of the cumulative normal, which prompts QUEST+ to explore both
% above and below the reference stimulus. In fitting and reporting the
% results we lock the mu to 0, which corresponds to being 50% accurate when
% there is no physical difference between the stimuli.

classdef PsychDiscrimFlickerThreshold < handle

    properties (Constant)
    end

    % Private properties
    properties (GetAccess=private)
    end

    % Calling function can see, but not modify
    properties (SetAccess=private)
        modResult
        questData
        simulatePsiParams
        simulateResponse
        simulateStimuli
        giveFeedback
        staircaseRule
        psychometricFuncHandle
        psiParamLabels
        stimParamsDomainList
        psiParamsDomainList
        randomizePhase = false;
        refFreqHz
        refContrast
        testContrast
        stimulusDurationSecs = 2;
        interStimulusIntervalSecs = 0.2;
    end

    % These may be modified after object creation
    properties (SetAccess=public)

        % The display object. This is modifiable so that we can re-load
        % a PsychDetectionThreshold, update this handle, and then continue
        % to collect data
        CombiLEDObj

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
        function obj = PsychDiscrimFlickerThreshold(CombiLEDObj,modResult,refFreqHz,varargin)

            % input parser
            p = inputParser; p.KeepUnmatched = false;
            p.addParameter('testContrast',0.333,@isnumeric);
            p.addParameter('refContrast',0.333,@isnumeric);
            p.addParameter('randomizePhase',false,@islogical);
            p.addParameter('simulateResponse',false,@islogical);
            p.addParameter('simulateStimuli',false,@islogical);
            p.addParameter('giveFeedback',true,@islogical);
            p.addParameter('useStaircase',true,@islogical);            
            p.addParameter('staircaseRule',[1,1],@isnumeric);
            p.addParameter('psychometricFuncHandle',@qpCumulativeNormalLapse,@ishandle);
            p.addParameter('psiParamLabels',{'μ','σ','λ'},@iscell);
            p.addParameter('simulatePsiParams',[0,0.3,0.05],@isnumeric);
            p.addParameter('stimParamsDomainList',linspace(0,1,51),@isnumeric);
            p.addParameter('psiParamsDomainList',...
                {linspace(0,0,1),linspace(0,3,51),linspace(0,0.1,11)},@isnumeric);
            p.addParameter('verbose',true,@islogical);
            p.parse(varargin{:})

            % Place various inputs and options into object properties
            obj.CombiLEDObj = CombiLEDObj;
            obj.modResult = modResult;
            obj.refFreqHz = refFreqHz;
            obj.testContrast = p.Results.testContrast;
            obj.refContrast = p.Results.refContrast;
            obj.randomizePhase = p.Results.randomizePhase;
            obj.simulateResponse = p.Results.simulateResponse;
            obj.simulateStimuli = p.Results.simulateStimuli;
            obj.giveFeedback = p.Results.giveFeedback;
            obj.useStaircase = p.Results.useStaircase;
            obj.staircaseRule = p.Results.staircaseRule;
            obj.psychometricFuncHandle = p.Results.psychometricFuncHandle;
            obj.psiParamLabels = p.Results.psiParamLabels;
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

            % Initialize the CombiLED
            obj.initializeDisplay;

            % There is a roll-off (attenuation) of the amplitude of
            % modulations with frequency. The stimParamsDomainList gives
            % the range of possible test frequencies (in dBs) relative to
            % the reference frequency. Check here that we can achieve the
            % called-for test and reference contrast given this.
            maxTestFreqHz = obj.refFreqHz * db2pow(max(obj.stimParamsDomainList));
            assert(obj.testContrast/contrastAttenuationByFreq(maxTestFreqHz) < 1);
            assert(obj.refContrast/contrastAttenuationByFreq(obj.refFreqHz) < 1);

        end

        % Required methds
        initializeQP(obj)
        initializeDisplay(obj)
        presentTrial(obj)
        stimParam = staircase(obj,currTrialIdx);
        [intervalChoice, responseTimeSecs] = getSimulatedResponse(obj,qpStimParams,testInterval)
        waitUntil(obj,stopTimeSeconds)
        [psiParamsQuest, psiParamsFit, psiParamsCI, fVal] = reportParams(obj,options)
        [psiParamsQuest, psiParamsFit, psiParamsCI, fVal] = reportCombinedParams(obj1, obj2, options)
        figHandle = plotOutcome(obj,visible)
        resetSearch(obj)
    end
end

