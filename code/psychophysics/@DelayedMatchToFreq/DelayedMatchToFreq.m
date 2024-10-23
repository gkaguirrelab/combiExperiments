% Object to support a two-interval delayed match-to-sample task in which
% the observer attempts to match the frequency of a presented stimulus. The
% measurement uses the method of constant stimuli.

classdef DelayedMatchToFreq < handle

    properties (Constant)
    end

    % Private properties
    properties (GetAccess=private)
    end

    % Calling function can see, but not modify
    properties (SetAccess=private)

        refFreqRangeHz
        refContrast
        testContrast
        testRangeDecibels
        randomizePhase
        trialData

        simulateResponse
        simulateStimuli
        refDurationSecs = 2;
        interStimulusIntervalSecs = 2;
        testRefreshIntervalSecs = 0.1;
        testFreqChangeRateDbsPerSec = 5;
    end

    % These may be modified after object creation
    properties (SetAccess=public)

        % The display object. This is modifiable so that we can re-load
        % a CollectFreqMatchTriplet, update this handle, and then continue
        % to collect data
        CombiLEDObj

        % Verbosity
        verbose = true;
        blockIdx = 1;
        blockStartTimes = datetime();

        % We allow this to be modified so we can set it to be brief during
        % object initiation when we clear the responses. Set to an
        % arbitrarily large number to allow the subject unbounded time to
        % respond.
        testDurationSecs = inf;
        
    end

    methods

        % Constructor
        % logTestBound = 
        function obj = DelayedMatchToFreq(CombiLEDObj,refFreqRangeHz,testContrast,varargin)

            % input parser
            p = inputParser; p.KeepUnmatched = false;
            p.addParameter('randomizePhase',false,@islogical);
            p.addParameter('simulateResponse',false,@islogical);
            p.addParameter('simulateStimuli',false,@islogical);
            p.addParameter('refContrast',0.5,@isnumeric);
            p.addParameter('testRangeDecibels',8,@isnumeric);
            p.addParameter('verbose',true,@islogical);
            p.parse(varargin{:})

            % Place various inputs and options into object properties
            obj.CombiLEDObj = CombiLEDObj;
            obj.refFreqRangeHz = refFreqRangeHz;
            obj.testContrast = testContrast;
            obj.refContrast = p.Results.refContrast;
            obj.testRangeDecibels = p.Results.testRangeDecibels;
            obj.randomizePhase = p.Results.randomizePhase;
            obj.simulateResponse = p.Results.simulateResponse;
            obj.simulateStimuli = p.Results.simulateStimuli;
            obj.verbose = p.Results.verbose;

            % Detect incompatible simulate settings
            if obj.simulateStimuli && ~obj.simulateResponse
                fprintf('Forcing simulateResponse to true, as one cannot respond to a simulated stimulus\n')
                obj.simulateResponse = true;
            end

            % Initialize the blockStartTimes field
            obj.blockStartTimes(1) = datetime();
            obj.blockStartTimes(1) = [];

            % Initialize the CombiLED
            obj.initializeDisplay;

            % There is a roll-off (attenuation) of the amplitude of
            % modulations with frequency. We account for this property by
            % "boosting" the contrast of the delivered stimulus, with the
            % amount of boost varying by frequency. We need to check for
            % the highest frequency that we will present that the boosted
            % contrast is not greater than unity.
            highestTestFreq = max(refFreqRangeHz)*db2mag(obj.testRangeDecibels);
            if (obj.testContrast / contrastAttenuationByFreq(highestTestFreq)) > 1
                error('The specified stimulus contrast is greater than can be presented for the highest test frequency')
            end
            if (obj.refContrast / contrastAttenuationByFreq(max(refFreqRangeHz))) > 1
                error('The specified stimulus contrast is greater than can be presented for the highest ref frequency')
            end
        end

        % Required methds
        initializeDisplay(obj)
        presentTrial(obj)
        [intervalChoice, responseTimeSecs] = getResponse(obj)
        [intervalChoice, responseTimeSecs] = getSimulatedResponse(obj,qpStimParams,ref1Interval)
        waitUntil(obj,stopTimeMicroSeconds)
        figHandle = plotOutcome(obj,visible)
    end
end