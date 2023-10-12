% Object to support nulling of the luminance component of chromatic
% modulations. A "target" modResult is passed to the routine, as well as an
% option "silent" modResult. The object then searchs over weights on the
% high and low settings of the target modulation. The candidate modulation
% is flickered at a high (e.g., 30 Hz) frequency and presented within a
% 2AFC detection trial. The weights are under the control of a quest+
% search using a psychometric function that attempts to find the null point
% at which the subject is at chance in detecting the flicker. 


classdef PsychFlickerNull < handle

    properties (Constant)
    end

    % Private properties
    properties (GetAccess=private)
    end

    % Calling function can see, but not modify
    properties (SetAccess=private)
        modResult
        adjustSettingsVec
        simulatePsiParams
        simulateResponse
        simulateStimuli
        giveFeedback
        psiParamsDomainList
        randomizePhase = true;
        adjustHighSettings
        stimFreqHz
        stimContrast
        stimTestSet
        pulseDurSecs = 1;
        halfCosineRampDurSecs = 0.125
        interStimulusIntervalSecs = 0.1;
    end

    % These may be modified after object creation
    properties (SetAccess=public)


        % We allow this to be modified so that one may combine measurements
        % from across psychometric objects, place the combined data into
        % this variable, and make use of the plotting and reporting methods
        questData

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
        function obj = PsychFlickerNull(CombiLEDObj,modResult,varargin)

            % input parser
            p = inputParser; p.KeepUnmatched = false;
            p.addParameter('adjustSettingsVec',ones(8,1),@isnumeric);
            p.addParameter('stimFreqHz',30,@isnumeric);
            p.addParameter('stimContrast',0.25,@isnumeric);
            p.addParameter('randomizePhase',false,@islogical);
            p.addParameter('simulateResponse',false,@islogical);
            p.addParameter('simulateStimuli',false,@islogical);
            p.addParameter('giveFeedback',true,@islogical);
            p.addParameter('adjustHighSettings',true,@islogical);
            p.addParameter('stimTestSet',linspace(-0.5,0.5,31),@isnumeric);
            p.addParameter('simulatePsiParams',[-0.08, 0.04, 0.50],@isnumeric);
            p.addParameter('psiParamsDomainList',{...
                linspace(-0.5,0.5,31), ...
                linspace(0.01,0.25,10),...
                linspace(0.50,0.75,10),...
                },@isnumeric);
            p.addParameter('verbose',true,@islogical);
            p.parse(varargin{:})

            % Place various inputs and options into object properties
            obj.CombiLEDObj = CombiLEDObj;
            obj.modResult = modResult;
            obj.adjustSettingsVec = p.Results.adjustSettingsVec;
            obj.stimFreqHz = p.Results.stimFreqHz;
            obj.stimContrast = p.Results.stimContrast;            
            obj.stimTestSet = p.Results.stimTestSet;           
            obj.adjustHighSettings = p.Results.adjustHighSettings;
            obj.randomizePhase = p.Results.randomizePhase;
            obj.simulateResponse = p.Results.simulateResponse;
            obj.simulateStimuli = p.Results.simulateStimuli;
            obj.giveFeedback = p.Results.giveFeedback;
            obj.simulatePsiParams = p.Results.simulatePsiParams;
            obj.psiParamsDomainList = p.Results.psiParamsDomainList;
            obj.verbose = p.Results.verbose;

            % Check that there is headroom in the modResult

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

        end

        % Required methods
        initializeQP(obj)
        initializeDisplay(obj)
        modResult = returnAdjustedModResult(obj,adjustWeight)
        validResponse = presentTrial(obj)
        [intervalChoice, responseTimeSecs] = getResponse(obj)
        [intervalChoice, responseTimeSecs] = getSimulatedResponse(obj,qpStimParams,testInterval)
        waitUntil(obj,stopTimeMicroSeconds)
        [psiParamsQuest, psiParamsFit, psiParamsCI, fVal] = reportParams(obj,options)
        figHandle = plotOutcome(obj,visible)
        resetSearch(obj)
    end
end