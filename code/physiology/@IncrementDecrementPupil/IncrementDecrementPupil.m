% Object to control the collection of pupillometry data for increments and
% decrements of a modulation around a spectral background
classdef IncrementDecrementPupil < handle

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
        simulateStimuli
        simulateRecording

        % Some stimulus properties
        halfCosineRampDurSecs
        trialData
        preTrialJitterRangeSecs
        pulseDurSecs
        postPulseRecordingDurSecs
    end

    % These may be modified after object creation
    properties (SetAccess=public)

        % The display object. This is modifiable so that we can re-load
        % the experimental object, update this handle, and then continue
        % to collect data
        CombiLEDObj

        % We can adjust the trialIdx if we are continuing data collection
        % after a break
        trialIdx = 1;

        % The stimuli
        stimContrast

        % A prefix to be added to the data files
        filePrefix

        % Verbosity
        verbose;

    end

    methods

        % Constructor
        function obj = IncrementDecrementPupil(CombiLEDObj,subjectID,modResult,varargin)

            % input parser
            p = inputParser; p.KeepUnmatched = false;
            p.addParameter('pupilVidStartDelaySec',5.0,@isnumeric);
            p.addParameter('preTrialJitterRangeSecs',[0 1],@isnumeric);
            p.addParameter('pulseDurSecs',6.0,@isnumeric);
            p.addParameter('postPulseRecordingDurSecs',10,@isnumeric);
            p.addParameter('stimContrast',1.0,@isnumeric);
            p.addParameter('halfCosineRampDurSecs',0.25,@isnumeric);
            p.addParameter('simulateStimuli',false,@islogical);
            p.addParameter('simulateRecording',false,@islogical);
            p.addParameter('dropBoxBaseDir',fullfile(getpref('combiLEDToolbox','dropboxBaseDir'),'MELA_data'),@ischar);
            p.addParameter('projectName','combiLED',@ischar);
            p.addParameter('experimentName','IncrementDecrementPupil',@ischar);
            p.addParameter('sessionID',string(datetime('now','Format','yyyy-MM-dd')),@ischar);
            p.addParameter('verbose',true,@islogical);
            p.parse(varargin{:})

            % Place various inputs and options into object properties
            obj.CombiLEDObj = CombiLEDObj;
            obj.pupilVidStartDelaySec = p.Results.pupilVidStartDelaySec;
            obj.preTrialJitterRangeSecs = p.Results.preTrialJitterRangeSecs;
            obj.pulseDurSecs = p.Results.pulseDurSecs;
            obj.postPulseRecordingDurSecs = p.Results.postPulseRecordingDurSecs;
            obj.stimContrast = p.Results.stimContrast;
            obj.halfCosineRampDurSecs = p.Results.halfCosineRampDurSecs;
            obj.simulateStimuli = p.Results.simulateStimuli;
            obj.simulateRecording = p.Results.simulateRecording;
            obj.verbose = p.Results.verbose;

            % Configure the combiLED
            if ~obj.simulateStimuli
                obj.CombiLEDObj.setSettings(modResult);
                obj.CombiLEDObj.setWaveformIndex(2); % square-wave
                obj.CombiLEDObj.setFrequency(1/(2*obj.pulseDurSecs));
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

            % Create a file prefix for the raw data from the stimulus
            % properties
            filePrefix = sprintf('trial_%02d_',obj.trialIdx);

            % Calculate the length of pupil recording needed.
            pupilRecordingTime = ...
                obj.pupilVidStartDelaySec + obj.pulseDurSecs + ...
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