% Object to control the collection of ssVEP and pupillometry data for a
% particular amplitude modulated flicker

classdef FlickerPhysio < handle

    properties (Constant)
    end

    % Private properties
    properties (GetAccess=private)
    end

    % Calling function can see, but not modify
    properties (SetAccess=private)
        pupilObj
        vepObj
        dataOutDir
        pupilVidStartDelaySec
        simulateStimuli

        % Some stimulus properties
        interStimIntervalSecs
        halfCosineRampDurSecs
        trialData
        preTrialJitterRangeSecs
        pulseDurSecs
    end

    % These may be modified after object creation
    properties (SetAccess=public)

        % The display object. This is modifiable so that we can re-load
        % a CollectFreqMatchTriplet, update this handle, and then continue
        % to collect data
        CombiLEDObj

        % We can adjust the trialIdx if we are continuing data collection
        % after a break
        trialIdx = 1;

        % The stimuli
        stimFreqHz
        stimContrastSet
        stimContrastOrder

        % A prefix to be added to the data files
        filePrefix

        % Verbosity
        verbose;

    end

    methods

        % Constructor
        function obj = FlickerPhysio(CombiLEDObj,subjectID,modDirection,experimentName,varargin)

            % input parser
            p = inputParser; p.KeepUnmatched = false;
            p.addParameter('pupilVidStartDelaySec',2.5,@isnumeric);
            p.addParameter('preTrialJitterRangeSecs',[0 1],@isnumeric);
            p.addParameter('stimFreqHz',20,@isnumeric);
            p.addParameter('stimContrastSet',[0,0.2,0.4,0.8],@isnumeric);
            p.addParameter('stimContrastOrder',[3,3,3,4,3,1,4,2,2,1,1,3,2,4,4,1,2],@isnumeric);
            p.addParameter('pulseDurSecs',2,@isnumeric);
            p.addParameter('halfCosineRampDurSecs',0.1,@isnumeric);
            p.addParameter('interStimIntervalSecs',0.2,@isnumeric);
            p.addParameter('simulateStimuli',false,@islogical);
            p.addParameter('dropBoxBaseDir',fullfile(getpref('combiLEDToolbox','dropboxBaseDir'),'MELA_data'),@ischar);
            p.addParameter('projectName','combiLED',@ischar);
            p.addParameter('verbose',true,@islogical);
            p.parse(varargin{:})

            % Place various inputs and options into object properties
            obj.CombiLEDObj = CombiLEDObj;
            obj.pupilVidStartDelaySec = p.Results.pupilVidStartDelaySec;
            obj.preTrialJitterRangeSecs = p.Results.preTrialJitterRangeSecs;
            obj.stimFreqHz = p.Results.stimFreqHz;
            obj.stimContrastSet = p.Results.stimContrastSet;
            obj.stimContrastOrder = p.Results.stimContrastOrder;            
            obj.pulseDurSecs = p.Results.pulseDurSecs;
            obj.interStimIntervalSecs = p.Results.interStimIntervalSecs;
            obj.halfCosineRampDurSecs = p.Results.halfCosineRampDurSecs;
            obj.simulateStimuli = p.Results.simulateStimuli;
            obj.verbose = p.Results.verbose;

            % Define the dir in which to save the trial
            obj.dataOutDir = fullfile(...
                p.Results.dropBoxBaseDir,...
                p.Results.projectName,...
                subjectID,modDirection,experimentName);

            % Create the directory if it isn't there
            if ~isfolder(obj.dataOutDir)
                mkdir(obj.dataOutDir)
            end

            % Create a file prefix for the raw data from the stimulus
            % properties
            filePrefix = sprintf('freq_%2.1f_trial_%02d_',obj.stimFreqHz,obj.trialIdx);

            % Calculate the length of pupil recording needed. We add a
            % second at the end to account for each cycle being slightly
            % longer than the specified cycle duration
            pupilRecordingTime = ...
                length(obj.stimContrastOrder)*(obj.pulseDurSecs + obj.interStimIntervalSecs) + ...
                obj.pupilVidStartDelaySec + 1;            

            % Initialize the pupil recording object.
            obj.pupilObj = PupilLabsControl(fullfile(obj.dataOutDir,'rawPupilVideos'),...
                'filePrefix',filePrefix,...
                'trialDurationSecs',pupilRecordingTime,...
                'backgroundRecording',true);

            % Initialize the ssVEP recording object
            obj.vepObj = BiopackControl(fullfile(obj.dataOutDir,'rawEEGData'),...
                'filePrefix',filePrefix,...
                'trialDurationSecs',obj.pulseDurSecs);

        end

        % Required methods
        collectTrial(obj)
        waitUntil(obj,stopTimeMicroSeconds)
    end
end