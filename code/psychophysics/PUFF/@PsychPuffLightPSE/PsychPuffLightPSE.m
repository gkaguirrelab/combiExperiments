% Object to support conducting a 2AFC air puff discrimination task,
% using QUEST+ to select stimuli in an effort to estimate the sigma (slope)
% of a cumulative normal Gaussian. Test stimuli above or below the
% reference frequency are examined in separate calls to this routine.

classdef PsychPuffLightPSE < handle

    properties (Constant)
    end

    % Private properties
    properties (GetAccess=private)
    end

    % Calling function can see, but not modify
    properties (SetAccess=private)
        maxAllowedPressurePSI = 45;
        maxAllowedRefPSIPerSec = 1;
        modResult
        questData
        simulatePsiParams
        simulateResponse
        simulateStimuli
        giveFeedback
        stimParamsDomainList
        psiParamsDomainList
        lightPulseModContrast
        lightPulseWaveform
        lightPulseDurSecs = 4;
        refPuffPSI
        puffDurSecs;
        prePuffLightSecs
        itiRangeSecs
        isiSecs = 1;
        trialLabel
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
        function obj = PsychPuffLightPSE(AirPuffObj,irCameraObj,LightObj,refPuffPSI,modResult,varargin)

            % input parser
            p = inputParser; p.KeepUnmatched = false;
            p.addParameter('trialLabel','',@ischar);            
            p.addParameter('simulateResponse',false,@islogical);
            p.addParameter('simulateStimuli',false,@islogical);
            p.addParameter('giveFeedback',true,@islogical);
            p.addParameter('lightPulseModContrast',0.5,@isnumeric);
            p.addParameter('lightPulseWaveform','background',@ischar);
            p.addParameter('puffDurSecs',0.33,@isnumeric);
            p.addParameter('prePuffLightSecs',3,@isnumeric);
            p.addParameter('itiRangeSecs',[1,1.5],@isnumeric);
            p.addParameter('simulatePsiParams',[.2,0.5],@isnumeric);
            p.addParameter('stimParamsDomainList',linspace(-3,3,25),@isnumeric);
            p.addParameter('psiParamsDomainList',...
                {linspace(-1,1,11),linspace(0,3,15)},@isnumeric);
            p.addParameter('verbose',true,@islogical);
            p.parse(varargin{:})

            % Place various inputs and options into object properties
            obj.AirPuffObj = AirPuffObj;
            obj.irCameraObj = irCameraObj;            
            obj.LightObj = LightObj;
            obj.refPuffPSI = refPuffPSI;
            obj.modResult = modResult;
            obj.trialLabel = p.Results.trialLabel;
            obj.simulateResponse = p.Results.simulateResponse;
            obj.simulateStimuli = p.Results.simulateStimuli;
            obj.giveFeedback = p.Results.giveFeedback;
            obj.lightPulseModContrast = p.Results.lightPulseModContrast;
            obj.lightPulseWaveform = p.Results.lightPulseWaveform;
            obj.puffDurSecs = p.Results.puffDurSecs;
            obj.prePuffLightSecs = p.Results.prePuffLightSecs;            
            obj.itiRangeSecs = p.Results.itiRangeSecs;
            obj.simulatePsiParams = p.Results.simulatePsiParams;
            obj.stimParamsDomainList = p.Results.stimParamsDomainList;
            obj.psiParamsDomainList = p.Results.psiParamsDomainList;
            obj.verbose = p.Results.verbose;

            % Detect incompatible simulate settings
            if obj.simulateStimuli && ~obj.simulateResponse
                fprintf('Forcing simulateResponse to true, as one cannot respond to a simulated stimulus\n')
                obj.simulateResponse = true;
            end

            % Check that the max required pressure is within the safety
            % range
            maxPressurePSI = obj.refPuffPSI * db2pow(max(obj.stimParamsDomainList));
            if maxPressurePSI > obj.maxAllowedPressurePSI
                warning('Measurements will be limited by max allowed pressure');
            end

            % Check that the PSI * stimulus duration is not greater than
            % maxAllowedRefPSIPerSec
            if obj.refPuffPSI*obj.puffDurSecs > obj.maxAllowedRefPSIPerSec
                error('The PSI * duration of the reference stimulus exceeds the safety limit');
            end

            % Initialize the blockStartTimes field
            obj.blockStartTimes(1) = datetime();
            obj.blockStartTimes(1) = [];

            % Initialize Quest+
            obj.initializeQP;

            % Initialize the CombiLED
            obj.initializeDisplay;

        end

        % Required methds
        initializeQP(obj)
        initializeDisplay(obj)
        presentTrial(obj)
        [intervalChoice, responseTimeSecs] = getSimulatedResponse(obj,qpStimParams,testInterval)
        [intervalChoice, responseTimeSecs] = getResponse(obj);
        waitUntil(obj,stopTimeSeconds)
        [psiParamsQuest, psiParamsFit, psiParamsCI, fVal] = reportParams(obj,options)
        figHandle = plotOutcome(obj,visible)
        resetSearch(obj)
    end
end