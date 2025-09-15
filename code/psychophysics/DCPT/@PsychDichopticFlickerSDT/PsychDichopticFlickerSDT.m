% Object to support conducting a single-interval, "signal detection" style
% measurement. Within a split hemi-field dichoptic display the observer is
% shown flickering lights, one at the reference frequency and one at a test
% frequency. The observer indicates if the frequency of the flicker is the
% same or different on the two sides. An adaptive procedure is used to
% determine the test frequency, guided by a psychometric function that
% estimates the false positive rate, the threshold frequency difference (in
% dB) that corresponds to d'= 1, and the steepness of the discrimination
% function. The occurence of "0 dB" trials is enhanced at the start of the
% testing procedure so that around 50% of the initial trials present
% the same flicker frequency on the two sides. The observer is given
% "correct" feedback for hits and correct rejections. The adaptive
% procedure results in about an 80% correct rate overall.

classdef PsychDichopticFlickerSDT < handle

    properties (Constant)
    end

    % Private properties
    properties (GetAccess=private)
    end

    % Calling function can see, but not modify
    properties (SetAccess=private)
        % The range of psychometric function parameter values that QUEST+
        % will consider
        psiParamsDomainList

        % The psychometric function used to guide QUEST+
        psychometricFuncHandle

        % The parameters of the QUEST+ object, and the accumulated trial
        % data
        questData

        modResultArr
        relativePhotoContrastCorrection
        simulatePsiParams
        giveFeedback
        psiParamLabels
        stimParamsDomainList
        refFreqHz
        refPhotoContrast
        refModContrast
        testPhotoContrast
        testModContrast
        stimDurSecs
        rampDurSecs
        trialStartDelaySecs
        combiLEDStartTimeSecs = 0.03;
        stimParamSide
    end

    % These may be modified after object creation
    properties (SetAccess=public)

        % A cell array of the display objects. This is modifiable so that
        % we can re-load a PsychDetectionThreshold, update this handle, and
        % then continue to collect data
        CombiLEDObjArr

        % Object for EOG recording using Biopac
        EOGControl

        % Can switch between simulating and not simulating
        simulateMode

        % Assign a filename which is handy for saving and loading
        filename

        % Verbosity
        verbose = true;
        blockIdx = 1;
        blockStartTimes = datetime();

        % Choose between keyboard and gamepad
        useKeyboardFlag

    end

    methods

        % Constructor
        function obj = PsychDichopticFlickerSDT(CombiLEDObjArr,modResultArr,EOGControl,refFreqHz,varargin)

            % input parser
            p = inputParser; p.KeepUnmatched = false;           
            p.addParameter('stimParamSide','hi',@ischar); % valid values {'hi','low'}
            p.addParameter('refPhotoContrast',0.1,@isnumeric);
            p.addParameter('testPhotoContrast',0.1,@isnumeric);
            p.addParameter('stimDurSecs',3,@isnumeric);
            p.addParameter('rampDurSecs', 0.5,@isnumeric);
            p.addParameter('trialStartDelaySecs', 0.5,@isnumeric);
            p.addParameter('simulateMode',false,@islogical);
            p.addParameter('giveFeedback',true,@islogical);
            p.addParameter('psychometricFuncHandle',@LesmesTransducerFunc,@ishandle);
            p.addParameter('psiParamLabels',{'fpRate','τ','γ'},@iscell);
            p.addParameter('simulatePsiParams',[0.05,1,1],@isnumeric);
            p.addParameter('stimParamsDomainList',[0 logspace(log10(0.1),log10(5),30)],@isnumeric);
            p.addParameter('psiParamsDomainList',...
                {linspace(0.001,0.251,15),linspace(0.1,3.1,15),logspace(-0.3,0.7,15)},@isnumeric);
            p.addParameter('verbose',true,@islogical);
            p.addParameter('useKeyboardFlag',false,@islogical);
            p.parse(varargin{:})

            % Place various inputs and options into object properties
            obj.CombiLEDObjArr = CombiLEDObjArr;
            obj.modResultArr = modResultArr;
            obj.EOGControl = EOGControl;
            obj.refFreqHz = refFreqHz;
            obj.stimParamSide = p.Results.stimParamSide;
            obj.testPhotoContrast = p.Results.testPhotoContrast;
            obj.refPhotoContrast = p.Results.refPhotoContrast;            
            obj.stimDurSecs = p.Results.stimDurSecs;            
            obj.rampDurSecs = p.Results.rampDurSecs;
            obj.trialStartDelaySecs = p.Results.trialStartDelaySecs;           
            obj.simulateMode = p.Results.simulateMode;
            obj.giveFeedback = p.Results.giveFeedback;
            obj.psychometricFuncHandle = p.Results.psychometricFuncHandle;
            obj.psiParamLabels = p.Results.psiParamLabels;
            obj.simulatePsiParams = p.Results.simulatePsiParams;
            obj.stimParamsDomainList = p.Results.stimParamsDomainList;
            obj.psiParamsDomainList = p.Results.psiParamsDomainList;
            obj.verbose = p.Results.verbose;
            obj.useKeyboardFlag = p.Results.useKeyboardFlag;

            % Initialize the blockStartTimes field
            obj.blockStartTimes(1) = datetime();
            obj.blockStartTimes(1) = [];

            % Initialize Quest+
            obj.initializeQP;

            % Determine the modulation contrast depth that produces the
            % desired photoreceptor contrast on average across the two
            % combiLEDs
            for side = 1:2
                maxPhotoContrast(side) = mean(abs(modResultArr{side}.contrastReceptorsBipolar(modResultArr{side}.meta.whichReceptorsToTarget)));
            end
            meanMaxPhotoContrast = mean(maxPhotoContrast);
            obj.testModContrast = obj.testPhotoContrast / meanMaxPhotoContrast;
            obj.refModContrast = obj.refPhotoContrast / meanMaxPhotoContrast;

            % Check the contrast on the targeted photoreceptors. This may
            % differ slightly for the modulations assigned to each
            % combiLED. We will calculate a contrast correction that is
            % applied to scale the larger contrast modulation to equate
            % them.
            relativePhotoContrast = maxPhotoContrast(1) / maxPhotoContrast(2);
            if relativePhotoContrast >= 1
                obj.relativePhotoContrastCorrection = [1/relativePhotoContrast,1];
            else
                obj.relativePhotoContrastCorrection = [1,relativePhotoContrast];
            end

            % There is a roll-off (attenuation) of the amplitude of
            % modulations with frequency. The stimParamsDomainList gives
            % the range of possible test frequencies (in dBs) relative to
            % the reference frequency. Check here that we can achieve the
            % called-for test and reference contrast given this.
            switch obj.stimParamSide
                case 'hi'
                    maxTestFreqHz = obj.refFreqHz * db2pow(max(obj.stimParamsDomainList));
                case 'low'
                    maxTestFreqHz = obj.refFreqHz / db2pow(max(obj.stimParamsDomainList));
            end
            assert(obj.testModContrast/contrastAttenuationByFreq(maxTestFreqHz) < 1);
            assert(obj.refModContrast/contrastAttenuationByFreq(obj.refFreqHz) < 1);
            
        end

        % Required methds
        initializeQP(obj)
        initializeDisplay(obj)
        presentTrial(obj,forceTestParam)
        stimParam = staircase(obj,currTrialIdx, stairCaseStartDb);
        [intervalChoice, responseTimeSecs] = getSimulatedResponse(obj,qpStimParams,testInterval)
        waitUntil(obj,stopTimeSeconds)
        [psiParamsQuest, psiParamsFit, psiParamsCI, fVal] = reportParams(obj,options)
        [psiParamsQuest, psiParamsFit, psiParamsCI, fVal] = reportCombinedParams(obj1, obj2, options)
        figHandle = plotOutcome(obj,visible)
        figHandle = plotOutcomeCombined(obj,objFileCellArray,visible)
        resetSearch(obj)
    end
end

