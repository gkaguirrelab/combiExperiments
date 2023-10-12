% Object to stream EEG data from a biopack unit via a LabJack connection

classdef BiopackControl < handle

    properties (Constant)
    end

    % Private properties
    properties (GetAccess=private)
    end

    % Calling function can see, but not modify
    properties (SetAccess=private)
        labjackOBJ
        recordingFreqHz = 2000;
        channelIdx = 1;
        dataOutDir
        trialData = [];
        simulateResponse
    end

    % These may be modified after object creation
    properties (SetAccess=public)

                trialIdx = 1;

        % A prefix to be added to the data files
        filePrefix

        % How long to record
        trialDurationSecs

        % Verbosity
        verbose

    end

    methods

        % Constructor
        function obj = BiopackControl(dataOutDir,varargin)

            % input parser
            p = inputParser; p.KeepUnmatched = false;
            p.addParameter('filePrefix','',@ischar);
            p.addParameter('trialDurationSecs',4,@isnumeric);
            p.addParameter('simulateResponse',false,@islogical);
            p.addParameter('verbose',false,@islogical);
            p.parse(varargin{:})

            % Place various inputs and options into object properties
            obj.filePrefix = p.Results.filePrefix;
            obj.trialDurationSecs = p.Results.trialDurationSecs;
            obj.simulateResponse = p.Results.simulateResponse;
            obj.verbose = p.Results.verbose;

            % Define the dir in which to save EEG data
            obj.dataOutDir = dataOutDir;

            % Create the directory if it isn't there
            if ~isfolder(obj.dataOutDir)
                mkdir(obj.dataOutDir)
            end

            % If we are not in simulate mode, setup the labjack
            if ~obj.simulateResponse

                % Open a labjack connection
                obj.labjackOBJ = LabJackU6('verbosity',double(obj.verbose));

                % Configure analog input sampling
                obj.labjackOBJ.configureAnalogDataStream(obj.channelIdx,obj.recordingFreqHz);

            end

        end

        % Required methds
        vepDataStruct = recordTrial(obj)
        storeTrial(obj,vepDataStruct,trialLabel)
        
    end
end