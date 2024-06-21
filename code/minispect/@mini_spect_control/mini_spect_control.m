% Object to support interfacing with the mini-spect light sensor

classdef mini_spect_control < handle

    properties (Constant)
        baudrate = 115200;
    end

    % Calling function can see, but not modify
    properties (SetAccess=private)
        END_MARKER = '!'
        serialObj
        deviceState

    end

    % These may be modified after object creation
    properties (SetAccess=public)
        
        % Verbosity
        verbose = false;

    end

    methods

        % Constructor
        function obj = mini_spect_control(varargin)

            % input parser
            p = inputParser; p.KeepUnmatched = false;
            p.addParameter('verbose',false,@islogical);
            p.parse(varargin{:})

            % Store the verbosity
            obj.verbose = p.Results.verbose;

            % Open the serial port
            obj.serialOpen_minispect();

        end

        % Required methds
        
        % Connection related
        serialOpen_minispect(obj)
        serialClose_minispect(obj)
        
        % I/O related
        result = read_minispect(obj, chip, mode)
        result = write_minispect(obj, chip, mode, write_val)


    end
end