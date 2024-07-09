% Object to support interfacing with the mini-spect light sensor

classdef mini_spect_control < handle

    properties (Constant)
        baudrate = 115200;
    end

    % Calling function can see, but not modify
    properties (SetAccess=private)
        % Map the name of chips to their underlying representations
        chip_name_map = containers.Map({'AMS7341','TSL2591','LIS2DUXS12','SEEED'}, {'A','T','L','S'})

        % Map the underlying representations of chips, to name of fields, to the fields' underlying representations
        chip_functions_map = containers.Map({'A', 'T', 'L','S'}, {  containers.Map({'Gain','Integration','Channels','Flicker','Power','ATIME','ASTEP'}, {'G', 'I','C','F','P','a','A'}), containers.Map({'Gain','Channels','Lux','Power','ATIME'}, {'G', 'C','L','P','A'}), containers.Map({'Accel','Power'}, {'A','P'}), containers.Map({'SerialNumber'}, {'S'}) })
        
        % Map the different chips to their different amount of available channels
        chip_nChannels_map = containers.Map({'A','T'},{10,2});

        % End of Message marker to mark end of Serial responses
        END_MARKER = '!'
        
        serial_number 
        serialObj

    end

    % These may be modified after object creation
    properties (SetAccess=public)
        % Allow user to access names of all chips on device 
        all_chip_names = ['AMS7341','TSL2591','LIS2DUXS12','SEEED'];

        % Allow users to access names of light-sensing chips only
        light_sensing_chips = ['AMS7341','TSL2591'];
        
        % Verbosity
        verbose = false;

        % Simulate or open actual device 
        simulate = false; 

    end

    methods

        % Constructor
        function obj = mini_spect_control(varargin)

            % input parser
            p = inputParser; p.KeepUnmatched = false;
            p.addParameter('verbose',false,@islogical);
            p.addParameter('simulate',false,@islogical);
            p.parse(varargin{:})

            % Store the verbosity
            obj.verbose = p.Results.verbose;

            % Store operation mode 
            obj.simulate = p.Results.simulate; 

            if obj.simulate
                return 
            end

            % Open the serial port
            obj.serialOpen_minispect();

            serial_number_output = obj.read_minispect('S','S');
            
            obj.serial_number = serial_number_output(end);

        end

        % Required methds
        
        % Connection related
        serialOpen_minispect(obj)
        serialClose_minispect(obj)
        
        % I/O related
        result = read_minispect(obj, chip, mode)
        result = write_minispect(obj, chip, mode, write_val)

        % Result parsing related 
        channel_values = parse_channel_reading(obj, reading, chip)

        % Calibration related 
        calibrate_minispect(obj,NDF,cal_path,nPrimarySteps,settingScalarRange,nSamplesPerStep,reps,randomizeOrder,save_path)
        test_integration_stability(obj,NDF,cal_path,chip);

    end
end