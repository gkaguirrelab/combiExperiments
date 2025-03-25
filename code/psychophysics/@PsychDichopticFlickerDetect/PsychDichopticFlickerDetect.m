% Object to support conducting a 2AFC flicker discrimination task,
% using QUEST+ to select stimuli in an effort to estimate the sigma (slope)
% of a cumulative normal Gaussian. The search is also asked to estimate the
% mu (mean) of the cumulative normal, which prompts QUEST+ to explore both
% above and below the reference stimulus. In fitting and reporting the
% results we lock the mu to 0, which corresponds to being 50% accurate when
% there is no physical difference between the stimuli.

classdef PsychDichopticFlickerDetect < handle

    properties (Constant)
    end

    % Private properties
    properties (GetAccess=private)
    end

    % Calling function can see, but not modify
    properties (SetAccess=private)
        modResultC
        modResultD
        questData
        simulatePsiParams
        giveFeedback
        staircaseRule % [nUp, nDown]
        psiParamLabels
        testLogContrastSet
        psiParamsDomainList
        randomizePhase = false;
        testFreqHz
        updateCombiLEDTimeSecs
        waitToRespondTimeSecs
    end

    % These may be modified after object creation
    properties (SetAccess=public)

        % The display objects. This is modifiable so that we can re-load
        % a PsychDetectionThreshold, update this handle, and then continue
        % to collect data
        CombiLEDObjC
        CombiLEDObjD

        % Can switch between using a staircase and QUEST+ to select the
        % next trial
        useStaircase

        % Can switch between simulating and not simulating
        simulateResponse
        simulateStimuli

        % Switch between randomly assigning non-zero flicker and 
        % always assigning it to the first Combi
        randomCombi

        % Assign a filename which is handy for saving and loading
        filename

        % Verbosity
        verbose = true;
        blockIdx = 1;
        blockStartTimes = datetime();

    end

    methods

        % Constructor
        function obj = PsychDichopticFlickerDetect(CombiLEDObjC, CombiLEDObjD, modResultC, modResultD, ...
                testFreqHz, varargin)
                
            % input parser
            p = inputParser; p.KeepUnmatched = false;
            p.addParameter('randomizePhase',true,@islogical);
            p.addParameter('simulateResponse',false,@islogical);
            p.addParameter('simulateStimuli',false,@islogical);
            p.addParameter('randomCombi',true,@islogical);
            p.addParameter('giveFeedback',true,@islogical);
            p.addParameter('updateCombiLEDTimeSecs',0.5,@isnumeric);
            p.addParameter('waitToRespondTimeSecs',0.5,@isnumeric);
            p.addParameter('useStaircase',true,@islogical);            
            p.addParameter('staircaseRule',[1,3],@isnumeric);
            p.addParameter('testLogContrastSet',linspace(-3,-0.3,31),@isnumeric);
            p.addParameter('psiParamLabels',{'thresh','slope','guess','lapse'},@iscell);
            p.addParameter('simulatePsiParams',[-2, 1.5, 0.5, 0.0],@isnumeric);
            p.addParameter('psiParamsDomainList',...
                {...
                linspace(-2.5,-0.3,21), ...
                logspace(log10(1),log10(10),21),...
                [0.5],...
                [0]...
                },@isnumeric);
            p.addParameter('verbose',true,@islogical);
            p.parse(varargin{:})

            % Place various inputs and options into object properties
            obj.CombiLEDObjC = CombiLEDObjC;
            obj.CombiLEDObjD = CombiLEDObjD;
            obj.modResultC = modResultC;
            obj.modResultD = modResultD;
            obj.testFreqHz = testFreqHz;
            obj.randomizePhase = p.Results.randomizePhase;
            obj.simulateResponse = p.Results.simulateResponse;
            obj.simulateStimuli = p.Results.simulateStimuli;
            obj.randomCombi = p.Results.randomCombi;
            obj.giveFeedback = p.Results.giveFeedback;
            obj.updateCombiLEDTimeSecs = p.Results.updateCombiLEDTimeSecs;
            obj.waitToRespondTimeSecs = p.Results.waitToRespondTimeSecs;
            obj.useStaircase = p.Results.useStaircase;
            obj.staircaseRule = p.Results.staircaseRule;
            obj.psiParamLabels = p.Results.psiParamLabels;
            obj.testLogContrastSet = p.Results.testLogContrastSet;
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

            % Initialize the CombiLEDs
            obj.initializeDisplay;

            % There is a roll-off (attenuation) of the amplitude of
            % modulations with frequency. The stimParamsDomainList gives
            % the range of possible test frequencies (in dBs) relative to
            % the reference frequency. Check here that we can achieve the
            % called-for test and reference contrast given this.  
            maxContrast = 10.^max(obj.testLogContrastSet);
            assert(maxContrast/contrastAttenuationByFreq(obj.testFreqHz) < 1);

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

