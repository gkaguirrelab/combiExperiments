% Object to support conducting a 2AFC flicker discrimination task. The
% testing procedure involves showing a binocular, dichoptic reference
% flicker of a specified frequency and photoreceptor contrast. The observer
% presses a button when they feel they have properly encoded the stimulus.
% After a variable delay the flicker returns, but on one side the flicker
% frequency has been changed. The observer is asked to report the side on
% which the change has occurred. QUEST+ is used to select stimuli in an
% effort to estimate the sigma (slope) of a cumulative normal Gaussian that
% defines the discrimination function. The mean (mu) is set to zero, which
% corresponds to being 50% accurate when there is no physical difference
% between the stimuli.

classdef PsychDichopticFlickerDiscrimSide < handle

    properties (Constant)
    end

    % Private properties
    properties (GetAccess=private)
    end

    % Calling function can see, but not modify
    properties (SetAccess=private)
        modResultArr
        relativePhotoContrastCorrection
        simulatePsiParams
        giveFeedback
        staircaseRule % [nUp, nDown]
        psiParamLabels
        stimParamsDomainList
        refFreqHz
        refPhotoContrast
        refModContrast
        testPhotoContrast
        testModContrast
        stimDurSecs
        isiSecs
        rampDurSecs
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

        % Indicate whether using EOG  
        EOGFlag

        % Can switch between using a staircase and QUEST+ to select the
        % next trial
        useStaircase

        % To set the staircase start value
        stairCaseStartDb

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

        %% The set of parameters below are modifiable as we wished to
        %% update the properties of a psychometric object for one subject
        %% after data collection had begun.

        % The range of psychometric function parameter values that QUEST+
        % will consider
        psiParamsDomainList

        % The psychometric function used to guide QUEST+
        psychometricFuncHandle

        % The parameters of the QUEST+ object, and the accumulated trial
        % data
        questData


    end

    methods

        % Constructor
        function obj = PsychDichopticFlickerDiscrimSide(CombiLEDObjArr, modResultArr, EOGControl, EOGFlag, refFreqHz,varargin)

            % input parser
            p = inputParser; p.KeepUnmatched = false;           
            p.addParameter('stimParamSide','hi',@ischar); % valid values {'hi','low'}
            p.addParameter('refPhotoContrast',0.1,@isnumeric);
            p.addParameter('testPhotoContrast',0.1,@isnumeric);
            p.addParameter('stimDurSecs',3,@isnumeric);
            p.addParameter('isiSecs',0.5,@isnumeric);
            p.addParameter('rampDurSecs', 0.5,@isnumeric);
            p.addParameter('simulateMode',false,@islogical);
            p.addParameter('giveFeedback',true,@islogical);
            p.addParameter('useStaircase',true,@islogical);
            p.addParameter('stairCaseStartDb',1,@isnumeric);
            p.addParameter('staircaseRule',[1,3],@isnumeric);
            p.addParameter('psychometricFuncHandle',@qpCumulativeNormalShifted,@ishandle);
            p.addParameter('psiParamLabels',{'μ','σ','λ'},@iscell);
            p.addParameter('simulatePsiParams',[0,2,0.00],@isnumeric);
            p.addParameter('stimParamsDomainList',linspace(0,1,51),@isnumeric);
            p.addParameter('psiParamsDomainList',...
                {linspace(0,5,25),linspace(0,6.75,51),linspace(0,0,1)},@isnumeric);
            p.addParameter('verbose',true,@islogical);
            p.addParameter('useKeyboardFlag',false,@islogical);
            p.parse(varargin{:})

            % Place various inputs and options into object properties
            obj.CombiLEDObjArr = CombiLEDObjArr;
            obj.modResultArr = modResultArr;
            obj.EOGControl = EOGControl;
            obj.refFreqHz = refFreqHz;
            obj.EOGFlag = EOGFlag;
            obj.stimParamSide = p.Results.stimParamSide;
            obj.testPhotoContrast = p.Results.testPhotoContrast;
            obj.refPhotoContrast = p.Results.refPhotoContrast;            
            obj.stimDurSecs = p.Results.stimDurSecs;            
            obj.isiSecs = p.Results.isiSecs;
            obj.rampDurSecs = p.Results.rampDurSecs;
            obj.simulateMode = p.Results.simulateMode;
            obj.giveFeedback = p.Results.giveFeedback;
            obj.useStaircase = p.Results.useStaircase;
            obj.stairCaseStartDb = p.Results.stairCaseStartDb;
            obj.staircaseRule = p.Results.staircaseRule;
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

            % Initialize the CombiLEDs
            obj.initializeDisplay;

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
        presentTrial(obj)
        stimParam = staircase(obj,currTrialIdx, stairCaseStartDb);
        [intervalChoice, responseTimeSecs] = getSimulatedResponse(obj,qpStimParams,testInterval)
        waitUntil(obj,stopTimeSeconds)
        [psiParamsQuest, psiParamsFit, psiParamsCI, fVal] = reportParams(obj,options)
        [psiParamsQuest, psiParamsFit, psiParamsCI, fVal] = reportCombinedParams(obj1, obj2, options)
        figHandle = plotOutcome(obj,visible)
        resetSearch(obj)
    end
end

