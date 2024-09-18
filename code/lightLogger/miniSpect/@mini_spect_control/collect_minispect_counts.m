function collect_minispect_counts(obj,NDF,calPath,nPrimarySteps,settingScalarRange,nSamplesPerStep,nReps,randomizeOrder,savePath,notificationAddress)
% Collects the counts and other info observed by the minispect of the combiLED taking various samples across a range 
% of scaled backgrounds.
%
% Syntax:
%   MS.collect_minispect_counts(NDF,calPath,nPrimarySteps,settingScalarRange,nSamplesPerStep,nReps,randomizeOrder,savePath,notificationAddress)
%
% Description:
%   Calibrates the minispect against the CombiLED with a given NDF filter nReps times, 
%   with nPrimarySteps between settingScalarRange, taking nSamplesPerStep samples per 
%   measure. The steps are presented either sequentially or randomly, defined by 
%   randomizeOrder. The results are saved to a subfolder labeled 
%   with the device ID of the minispect in a file named calibration[NDF]. Uses the 
%   cal file of the light source as a reference. 
%
% Inputs:
%   NDF                   - Int/Float. Represents the NDF filter level
%                           on the light source. 
%   calPath               - String. Represents the path to the light source
%                           calibration file.
%   nPrimarySteps         - Int. Represents the number of different setting values
%                           to present on the CombiLED.
%   settingScalarRange    - Tuple. Represents the percentage [low,high] bounds of the light 
%                           levels.
%   nSamplesPerStep       - Int. Represents the number of measures to take at a given 
%                           primary step. 
%   nReps                 - Int. Represents the number of repetitions to conduct the entire
%                           experiment over. 
%   randomizeOrder        - Logical. Represents whether or not to randomize the order
%                           in which primary settings are presented to the minispect
%   savePath              - String. Represents the path to the folder in which 
%                           calibrations of minispects are saved.  
%   notificationAddress   - String. Represents the email to notify when data collection 
%                           has finished.                    
%
% Outputs:
%   MSCalData             - Struct. Contains all of the meta data (params, timings, date, etc)
%                           as well as the raw data (counts, settings) used for calibration
%
% Examples:
%{
   calDir = fullfile(tbLocateProjectSilent('combiExperiments'),'cal');
   calFileName = 'CombiLED_shortLLG_sphere_ND0.mat';
   calPath = fullfile(calDir,calFileName);
   email = 'Zachary.Kelly@pennmedicine.upenn.edu'; 
   MS = mini_spect_control();
   MS.collect_minispect_counts(2,calPath,10,[0.05,0.95],10,3,true,'./calibration',email) 
%}

    % Ensure we have a real device connected
    if(obj.simulate)
        error('Cannot calibrate. Device in simulation mode.')
    end

    % Create input parser
    parser = inputParser; 

    % Add required arguments with type validation
    parser.addRequired('NDF', @(x) isnumeric(x) && isscalar(x)); % Ensure the NDF is a numeric, scalar value
    parser.addRequired('calPath', @(x) ischar(x) || isstring(x)); % Ensure the calPath is a string type
    parser.addRequired('nPrimarySteps', @(x) isnumeric(x) && isscalar(x)); % Ensure nPrimarySteps is a numeric, scalar value
    parser.addRequired('settingScalarRange', @(x) isnumeric(x) && isrow(x)); % Ensures settingScalarRange is a row vector of scalar values
    parser.addRequired('nSamplesPerStep', @(x) isnumeric(x) && isscalar(x)); % Ensures nSamplesPerStep is a numeric, scalar value
    parser.addRequired('nReps', @(x) isnumeric(x) && isscalar(x)); % Ensures nReps is a numeric, scalar value
    parser.addRequired('randomizeOrder', @(x) islogical(x)); % Ensures randomize order is a boolean value
    parser.addRequired('savePath', @(x) ischar(x) || isstring(x)); % Ensures the savePath is of string type
    parser.addRequired('notificationAddress', @(x) ischar(x) || isstring(x)); % Ensures the email notification address

    % Parse the arguments
    parser.parse(NDF, calPath, nPrimarySteps, settingScalarRange, nSamplesPerStep, nReps, randomizeOrder, savePath, notificationAddress);

    % Retrieve the arguments from the parser
    NDF = parser.Results.NDF; 
    calPath = parser.Results.calPath; 
    nPrimarySteps = parser.Results.nPrimarySteps; 
    settingScalarRange = parser.Results.settingScalarRange; 
    nSamplesPerStep = parser.Results.nSamplesPerStep; 
    nReps = parser.Results.nReps; 
    randomizeOrder = parser.Results.randomizeOrder; 
    savePath = parser.Results.savePath; 
    notificationAddress = parser.Results.notificationAddress; 

    % Define the settings_scalars vector of n linearly spaced values between start, end 
    background_scalars_sorted = linspace(settingScalarRange(1),settingScalarRange(2),nPrimarySteps);

    % Load the cal file
    load(calPath,'cals');
    cal = cals{end};

    % Set initial background settings
    background = [1,1,1,1,1,1,1,1]; 

    % Select the chips we are going to calibrate
    chips = obj.light_sensing_chips;

    % Get the MiniSpect device's serial number
    deviceSerialNumber = obj.serial_number;

    % Initialize combiLED light source object
    CL = CombiLEDcontrol();

    % Update the combiLED's gamma table
    CL.setGamma(cal.processedData.gammaTable);

    % Extract some information regarding the light source that is being used to
    % calibrate the minispect
    sourceS = cal.rawData.S;
    sourceP_abs = cal.processedData.P_device;
    nSourcePrimaries = cal.describe.displayPrimariesNum;

    % Set up data struct
    MSCalData = struct;

    % Store the parameters used to generate
    parameters.NDF = NDF;
    parameters.nPrimarySteps = nPrimarySteps;
    parameters.nSamplesPerStep = nSamplesPerStep;
    parameters.nReps = nReps;
    parameters.randomizeOrder = randomizeOrder;

    % Store the metadata about the device, calibration file, and parameters
    MSCalData.meta.serialNumber = deviceSerialNumber;
    MSCalData.meta.source_calpath = calPath;
    MSCalData.meta.source_cal = cal; 
    MSCalData.meta.params = parameters;
    MSCalData.meta.date = datetime('now');
    ASChip.meta.nDetectorChannels = obj.chip_nChannels_map('A');
    TSChip.meta.nDetectorChannels = obj.chip_nChannels_map('T');
    
    % Initialize empty containers for the counts and measurement times for the AS chip
    ASChip.raw.counts = {};
    ASChip.raw.secsPerMeasure = {};
    
    % Initialize empty containers for the counts and measurement times for the TS chip
    TSChip.raw.counts = {};
    TSChip.raw.secsPerMeasure = {};
    
    % Store raw data about the settings used for the combiLED
    MSCalData.raw.background = background;
    MSCalData.raw.background_scalars = {};

    % Construct a shorthand map to both chip's struct by their CPP level name
    chip_struct_map = containers.Map({'A','T'},{ASChip,TSChip});

    disp('You now have 30 seconds to leave the room before measurement begins.');
    pause(30);

    % Perform desired repetitions of each setting
    for ii = 1:nReps
        % Define combiLED setting scalars and their order for this repetition
        order_map = containers.Map({true,false},{randperm(nPrimarySteps), 1:nPrimarySteps});
        background_scalars_order = order_map(randomizeOrder);

        % Finalized settings
        background_scalars = background_scalars_sorted(background_scalars_order);

        % Save the settings for this repetition
        MSCalData.raw.background_scalars{ii} = background_scalars;
        
        % For every chip we want to calibrate
        for cc = 1:numel(chips)
            fprintf("Chip: %s | Repetition: %d / %d\n", chips{cc}, ii, nReps);
            
            % Get the chip, its available functions, and the 
            % channel-reading function specifically
            chip = obj.chip_name_map(chips{cc});
            chip_functions = obj.chip_functions_map(chip);
            mode = chip_functions('Channels');
            
            % Retrieve the number of channels the chip can measure
            nDetectorChannels = obj.chip_nChannels_map(chip);
            
            % Initialize holder for measurements
            counts = nan(nSamplesPerStep,nPrimarySteps,nDetectorChannels);
            secsPerMeasure = nan(1,nPrimarySteps);

            % Run through every combiLED setting
            for jj = 1:nPrimarySteps
                fprintf("Primary Step: %d / %d\n", jj, nPrimarySteps);

                % Where the values from this timestep should be 
                % inserted into the count matrix
                sorted_index = background_scalars_order(jj);

                % Get the current combiLED setting
                primary_setting = background_scalars(jj);

                % Set the combiLED settings
                CL_settings = primary_setting * background;

                % Set primaries with combiLED settings
                CL.setPrimaries(CL_settings);
                    
                % Begin timing how long it takes to record n samples
                tic; 

                % Record N samples from the minispect
                for kk = 1:nSamplesPerStep
                    fprintf("Sample: %d / %d | Chip: %s \n", kk, nSamplesPerStep,chips{cc});
                    channel_values = obj.read_minispect(chip,mode);
        
                    counts(kk,sorted_index,:) = channel_values;
                end

                % Find total elapsed time and calculate 
                % time per measurement
                elapsed_time = toc; 

                time_per_measure = elapsed_time / nSamplesPerStep; 

                secsPerMeasure(1,sorted_index) = time_per_measure;

            end

            % Make sure all data was read properly
            if(any(isnan(counts)))
                error('NaNs present in counts');
            end

            % Retrieve the struct for a given chip
            chip_struct = chip_struct_map(chip);

            % Save per rep data for a given chip
            chip_struct.raw.counts{ii} = counts;
            chip_struct.raw.secsPerMeasure{ii} = secsPerMeasure;
            
            % Need to reassign because we are returned a copy, not a reference to the original struct
            chip_struct_map(chip) = chip_struct;

        end

    end % reps

    % Retrieve the data for each chip
    MSCalData.ASChip = chip_struct_map('A');
    MSCalData.TSChip = chip_struct_map('T');

    % Save the calibration results
    MS_cal_dir = fullfile(savePath, deviceSerialNumber);

    % Create the folder if it does not exist
    if(~isfolder(MS_cal_dir))
        mkdir(MS_cal_dir);
    end

    % Save the calibration data struct
    save(fullfile(MS_cal_dir,"calibration"+ndf2str(NDF)+".mat"),'MSCalData');

    % Close the serial ports with the external device (combiLED)
    CL.serialClose();
    clear CL;

    % Send an email message once completed
    sendmail(notificationAddress, 'MiniSpect Data Collection completed.')

end