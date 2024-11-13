% Object to support conducting a double-reference, two-interval forced
% choice psychophysical test in which a subject is presented with
% sequential modulations and selects one. This is an implementation of the
% Jogan & Stocker 2014 approach, although with Quest+ used to perform
% adaptive trial seleciton.

classdef PsychDoubleRefAFC < handle

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
        randomizePhase = true;
        testFreqHz
        testContrast
        testContrastAdjusted
        refFreqSetHz
        refContrastVector
        refContrastVectorAdjusted
        stimulusDurationSecs = 1;
        interFlickerIntervalSecs = 0.2;
        interStimulusIntervalSecs = 0.75;
    end

    % These may be modified after object creation
    properties (SetAccess=public)

        % The display object. This is modifiable so that we can re-load
        % a CollectFreqMatchTriplet, update this handle, and then continue
        % to collect data
        CombiLEDObj

        % Verbosity
        verbose = true;
        blockStartTimes = datetime();

        % We allow this to be modified so we
        % can set it to be brief during object
        % initiation when we clear the responses
        responseDurSecs = 3;

        % Labels to identify the contrast levels used. For example, this
        % might be the number of decibels relative to the threshold
        refContrastLabel
        testContrastLabel
        
    end

    methods

        % Constructor
        function obj = PsychDoubleRefAFC(CombiLEDObj,testFreqHz,testContrast,refFreqSetHz,refContrastVector,varargin)

            % input parser
            p = inputParser; p.KeepUnmatched = false;
            p.addParameter('randomizePhase',false,@islogical);
            p.addParameter('simulateResponse',false,@islogical);
            p.addParameter('simulateStimuli',false,@islogical);
            p.addParameter('giveFeedback',false,@islogical);
            p.addParameter('simulatePsiParams',[0.15, 0.05, -0.15],@isnumeric);
            p.addParameter('psiParamsDomainList',{linspace(0,0.5,51), ...
                linspace(0,0.5,51),...
                linspace(-0.25,0.25,51)},@isnumeric);            
            p.addParameter('testContrastLabel','undefined',@ischar);
            p.addParameter('refContrastLabel','undefined',@ischar);
            p.addParameter('verbose',true,@islogical);
            p.parse(varargin{:})

            % Place various inputs and options into object properties
            obj.CombiLEDObj = CombiLEDObj;
            obj.testFreqHz = testFreqHz;
            obj.testContrast = testContrast;
            obj.refFreqSetHz = refFreqSetHz;
            obj.refContrastVector = refContrastVector;
            obj.randomizePhase = p.Results.randomizePhase;
            obj.simulateResponse = p.Results.simulateResponse;
            obj.simulateStimuli = p.Results.simulateStimuli;
            obj.giveFeedback = p.Results.giveFeedback;
            obj.simulatePsiParams = p.Results.simulatePsiParams;
            obj.psiParamsDomainList = p.Results.psiParamsDomainList;
            obj.testContrastLabel = p.Results.testContrastLabel;            
            obj.refContrastLabel = p.Results.refContrastLabel;            
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
            % modulations with frequency. We can adjust for this property,
            % and detect those cases which are outside of our ability to
            % correct
            obj.refContrastVectorAdjusted = obj.refContrastVector ./ ...
                contrastAttentionByFreq(obj.refFreqSetHz);

            % Check that the adjusted contrast does not exceed unity
            mustBeInRange(obj.refContrastVectorAdjusted,0,1);

            % Now adjust the test contrast
            obj.testContrastAdjusted = obj.testContrast / ...
                contrastAttentionByFreq(obj.testFreqHz);

            % Check that the adjusted contrast does not exceed unity
            mustBeInRange(obj.testContrastAdjusted,0,1);

        end

        % Required methds
        initializeQP(obj)
        initializeDisplay(obj)
        validResponse = presentTrial(obj)
        [intervalChoice, responseTimeSecs] = getResponse(obj)
        [intervalChoice, responseTimeSecs] = getSimulatedResponse(obj,qpStimParams,ref1Interval)
        waitUntil(obj,stopTimeMicroSeconds)
        [psiParamsQuest, psiParamsFit, psiParamsCI, fVal] = reportParams(obj,options)
        figHandle = plotOutcome(obj,visible)
        values = forwardTransformVals(obj,refValues,testValue)
        values = inverseTransVals(obj,refValues,testValue)
    end
end