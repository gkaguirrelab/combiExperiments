% Object to control the collection of pupillometry data for increments and
% decrements of a modulation around a spectral background
classdef IncrementPupil < handle

    properties (Constant)
    end

    % Private properties
    properties (GetAccess=private)
    end

    % Calling function can see, but not modify
    properties (SetAccess=private)
        pupilObj
        dataOutDir
        pupilVidStartDelaySec
        pupilVidStopDelaySec
        simulateStimuli
        simulateRecording

        % Some stimulus properties
        modDirection
        halfCosineRampDurSecs
        trialData
        preTrialJitterRangeSecs
        prePulseRecordingDurSecs
        pulseDurSecs
        postPulseRecordingDurSecs
    end

    % These may be modified after object creation
    properties (SetAccess=public)

        % The display object. This is modifiable so that we can re-load
        % the experimental object, update this handle, and then continue
        % to collect data
        CombiLEDObj

        % Incremented with each tril
        trialIdx = 0;

        % The stimuli
        stimContrast

        % A prefix to be added to the data files
        filePrefix

        % Verbosity
        verbose;

    end

    methods

        % Constructor
        function obj = IncrementPupil(CombiLEDObj,subjectID,modResult,varargin)

            % input parser
            p = inputParser; p.KeepUnmatched = false;
            p.addParameter('pupilVidStartDelaySec',5.0,@isnumeric);
            p.addParameter('pupilVidStopDelaySec',4.0,@isnumeric);
            p.addParameter('preTrialJitterRangeSecs',[0 1],@isnumeric);
            p.addParameter('prePulseRecordingDurSecs',2,@isnumeric);
            p.addParameter('pulseDurSecs',15.0,@isnumeric);
            p.addParameter('postPulseRecordingDurSecs',15,@isnumeric);
            p.addParameter('stimContrast',1.0,@isnumeric);
            p.addParameter('halfCosineRampDurSecs',2,@isnumeric);
            p.addParameter('simulateStimuli',false,@islogical);
            p.addParameter('simulateRecording',false,@islogical);
            p.addParameter('dropBoxBaseDir',fullfile(getpref('combiLEDToolbox','dropboxBaseDir'),'MELA_data'),@ischar);
            p.addParameter('projectName','combiLED',@ischar);
            p.addParameter('experimentName','IncrementPupil',@ischar);
            p.addParameter('sessionID',string(datetime('now','Format','yyyy-MM-dd')),@ischar);
            p.addParameter('verbose',true,@islogical);
            p.parse(varargin{:})

            % Place various inputs and options into object properties
            obj.CombiLEDObj = CombiLEDObj;
            obj.pupilVidStartDelaySec = p.Results.pupilVidStartDelaySec;
            obj.pupilVidStopDelaySec = p.Results.pupilVidStopDelaySec;          
            obj.preTrialJitterRangeSecs = p.Results.preTrialJitterRangeSecs;           
            obj.prePulseRecordingDurSecs = p.Results.prePulseRecordingDurSecs;
            obj.pulseDurSecs = p.Results.pulseDurSecs;
            obj.postPulseRecordingDurSecs = p.Results.postPulseRecordingDurSecs;
            obj.stimContrast = p.Results.stimContrast;
            obj.halfCosineRampDurSecs = p.Results.halfCosineRampDurSecs;
            obj.simulateStimuli = p.Results.simulateStimuli;
            obj.simulateRecording = p.Results.simulateRecording;
            obj.verbose = p.Results.verbose;
            obj.modDirection = modResult.meta.whichDirection;

            % Configure the combiLED
            if ~obj.simulateStimuli
                obj.CombiLEDObj.setSettings(modResult);
                obj.CombiLEDObj.setUnimodal();
                obj.CombiLEDObj.setWaveformIndex(2); % square-wave
                obj.CombiLEDObj.setFrequency(1/(2*obj.pulseDurSecs));
                obj.CombiLEDObj.setPhaseOffset(pi);
                obj.CombiLEDObj.setAMFrequency(1/(2*obj.pulseDurSecs));
                obj.CombiLEDObj.setAMIndex(2); % half-cosine windowing
                obj.CombiLEDObj.setAMValues([obj.halfCosineRampDurSecs,0]); % half-cosine on; second value unused
                obj.CombiLEDObj.setDuration(obj.pulseDurSecs)
            end

            % Define the dir in which to save the trial
            obj.dataOutDir = fullfile(...
                p.Results.dropBoxBaseDir,...
                p.Results.projectName,...
                subjectID,...
                p.Results.experimentName,...
                modResult.meta.whichDirection,...
                p.Results.sessionID...
                );

            % Create the directory if it isn't there
            if ~isfolder(obj.dataOutDir)
                mkdir(obj.dataOutDir)
            end

            % The pupil recording object supports adding a file prefix to
            % each trial. We won't use this here and just set it to empty.
            filePrefix = '';

            % Calculate the length of pupil recording needed.
            pupilRecordingTime = ...
                obj.pupilVidStartDelaySec + ...
                obj.prePulseRecordingDurSecs + ...
                obj.pulseDurSecs + ...
                obj.postPulseRecordingDurSecs;

            % Initialize the pupil recording object.
            if ~obj.simulateRecording
                obj.pupilObj = PupilLabsControl(fullfile(obj.dataOutDir,'rawPupilVideos'),...
                    'filePrefix',filePrefix,...
                    'trialDurationSecs',pupilRecordingTime,...
                    'backgroundRecording',true);
            end

        end

        % Required methods
        collectTrial(obj)
        waitMilliseconds(obj,durationToWaitMs)
        waitUntil(obj,stopTime)
    end
end