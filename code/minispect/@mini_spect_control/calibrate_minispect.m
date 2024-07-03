function calibrate_minispect(obj,NDF,cal_path,nPrimarySteps,nSamplesPerStep,nReps,randomizeOrder,save_path)
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

    % Which Cal file to use (currently hard-coded)
    calDir = fullfile(tbLocateProjectSilent('combiExperiments'),'cal');
    calFileName = 'CombiLED_shortLLG_testSphere_ND0x2.mat';

    cal_path = fullfile(calDir,calFileName);

    % Load the cal file
    load(cal_path,'cals');
    cal = cals{end};

    % Retrieve background light setting 
    background = calcSettingsForD65(cal);

    % Initialize the chip we want and the mode for it to be in
    chip = obj.chip_name_map("AMS7341");
    chip_functions = obj.chip_functions_map(chip);
    mode = chip_functions('Channels');

    % Get the number of channels it can observe
    nDetectorChannels = obj.nChannels;

    % Get the device's serial number
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
    MSCalData.meta.nDetectorChannels = nDetectorChannels;
    MSCalData.meta.source_calpath = cal_path;
    MSCalData.meta.source_cal = cal; 
    MSCalData.meta.params = parameters;
    MSCalData.meta.date = datetime('now');

    MSCalData.raw.counts = {};
    MSCalData.raw.background_scalars = nan(nReps,nPrimarySteps);
    MSCalData.raw.secsPerMeasure = nan(nReps,nPrimarySteps);
    MSCalData.raw.background = background;

    % Perform desired repetitions of each setting
    for jj = 1:nReps
        fprintf("Repetition: %d / %d\n", jj, nReps);

        % Initialize holder for measurements
        counts = nan(nSamplesPerStep,nPrimarySteps,nDetectorChannels);

        % Define combiLED setting scalars and their order
        order_map = containers.Map({true,false},{randperm(nPrimarySteps),1:nPrimarySteps});
        setting_scalar_formula = @(ii) 0.05+((ii-1)/(nPrimarySteps-1))*0.9;
        setting_scalars_sorted = arrayfun(setting_scalar_formula, 1:nPrimarySteps);
        settings_order = order_map(randomizeOrder);

        % Finalized settings
        background_scalars = setting_scalars_sorted(settings_order);

        % Run through every combiLED setting
        for ii = 1:length(background_scalars)
            fprintf("Primary Step: %d / %d\n", ii, nPrimarySteps);

            % Where the values from this timestep should be 
            % inserted into the count matrix
            sorted_index = settings_order(ii);

            % Get the current combiLED setting
            primary_setting = background_scalars(ii);

            % Set the combiLED settings
            CL_settings = primary_setting * background;

            % Set primaries with combiLED settings
            CL.setPrimaries(CL_settings);

            tic; 

            % Record N samples from the minispect
            for kk = 1:nSamplesPerStep
                fprintf("Sample: %d / %d\n", kk, nSamplesPerStep);
                channel_values = obj.read_minispect(chip,mode);

                counts(kk,sorted_index,:) = channel_values;
            end

            % Find total elapsed time and calculate 
            % time per measurement
            elapsed_time = toc; 

            time_per_measure = elapsed_time / nSamplesPerStep; 

            MSCalData.raw.secsPerMeasure(jj,sorted_index) = time_per_measure;

        end

        % Make sure all data was read properly
        if(any(isnan(counts)))
            error('NaNs present in counts');
        end

        % Save raw counts and settings
        MSCalData.raw.counts{jj} = counts;
        MSCalData.raw.background_scalars(jj,:) = background_scalars;

    end % reps

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