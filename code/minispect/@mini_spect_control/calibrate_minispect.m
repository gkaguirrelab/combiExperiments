function calibrate_minispect(obj,NDF,cal_path,nPrimarySteps,settingScalarRange,nSamplesPerStep,nReps,randomizeOrder,save_path)
% Calibrates the minispect against the CombiLED with a given NDF filter, saves results
%
% Syntax:
%   MS.calibrate_minispect(NDF,cal_path,nPrimarySteps,nSamplesPerStep,nReps,randomizeOrder,save_path)
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
%   cal_path              - String. Represents the path to the light source
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
%   save_path             - String. Represents the path to the folder in which 
%                           calibrations of minispects are saved.                      
%
% Outputs:
%   MSCalData             - Struct. Contains all of the meta data (params, timings, date, etc)
%                           as well as the raw data (counts, settings) used for calibration
%
% Examples:
%{
   MS = mini_spect_control();
   MS.calibrate_minispect(2,'./calfile',10,[0.05,0.95],10,3,1,'./calibration') 
%}
    
    % Ensure we have a real device connected
    if(obj.simulate)
        error('Cannot calibrate. Device in simulation mode.')
    end

    % Type-check parameters
    if(~islogical(randomizeOrder))
        error("Ensure randomize order flag argument is of boolean/logical type");
    end

    % Hard Coded Parameters for now
    nPrimarySteps = 10;
    nSamplesPerStep = 10;
    nReps = 3;
    settingScalarRange = [0.05,0.95];

    % Define the settings_scalars vector
    background_scalars_sorted = linspace(settingScalarRange(1),settingScalarRange(2),nPrimarySteps);

    % Which Cal file to use (currently hard-coded)
    calDir = fullfile(tbLocateProjectSilent('combiExperiments'),'cal');
    calFileName = 'CombiLED_shortLLG_testSphere_ND0x2.mat';

    cal_path = fullfile(calDir,calFileName);

    % Load the cal file
    load(cal_path,'cals');
    cal = cals{end};

    % Retrieve background light setting 
    background = calcSettingsForD65(cal);

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

    parameters.NDF = NDF;
    parameters.nPrimarySteps = nPrimarySteps;
    parameters.nSamplesPerStep = nSamplesPerStep;
    parameters.nReps = nReps;
    parameters.randomizeOrder = randomizeOrder;

    MSCalData.meta.serialNumber = deviceSerialNumber;
    MSCalData.meta.source_calpath = cal_path;
    MSCalData.meta.source_cal = cal; 
    MSCalData.meta.params = parameters;
    MSCalData.meta.date = datetime('now');

    ASChip.meta.nDetectorChannels = obj.chip_nChannels_map('A');
    ASChip.raw.counts = {};
    ASChip.raw.secsPerMeasure = {};
    
    TSChip.meta.nDetectorChannels = obj.chip_nChannels_map('T');
    TSChip.raw.counts = {};
    TSChip.raw.secsPerMeasure = {};
    
    MSCalData.raw.background = background;
    MSCalData.raw.background_scalars = {};

    % Construct a shorthand map to both chip's struct by their CPP level name
    chip_struct_map = containers.Map({'A','T'},{ASChip,TSChip});

    % Perform desired repetitions of each setting
    for ii = 1:nReps
        % Define combiLED setting scalars and their order for this repetition
        order_map = containers.Map({true,false},{randperm(nPrimarySteps),1:nPrimarySteps});
        background_scalars_order = order_map(randomizeOrder);

        % Finalized settings
        background_scalars = background_scalars_sorted(background_scalars_order);

        % Save the settings for this repetition
        MSCalData.raw.background_scalars{ii} = background_scalars;
        
        % For every chip we want to calibrate
        for cc = 1:size(chips,2)
            fprintf("Chip: %s | Repetition: %d / %d\n", chips(cc), ii, nReps);
            
            % Get the chip, its available functions, and the 
            % channel-reading function specifically
            chip = obj.chip_name_map(chips(cc));
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

                tic; 

                % Record N samples from the minispect
                for kk = 1:nSamplesPerStep
                    fprintf("Sample: %d / %d | Chip: %s \n", kk, nSamplesPerStep,chips(cc));
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

    MSCalData.ASChip = chip_struct_map('A');
    MSCalData.TSChip = chip_struct_map('T');

    % Save the calibration results
    MS_cal_dir = fullfile(save_path,deviceSerialNumber);

    if(~isfolder(MS_cal_dir))
        mkdir(MS_cal_dir);
    end

    % Save the calibration data struct
    save(fullfile(MS_cal_dir,"calibration"+ndf2str(NDF)+".mat"),'MSCalData');

    % Close the serial ports with the external device (combiLED)
    CL.serialClose();
    clear CL;

end