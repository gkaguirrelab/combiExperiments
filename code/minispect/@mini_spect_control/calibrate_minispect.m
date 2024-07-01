function calibrate_minispect(obj,NDF,cal_path,nPrimarySteps,nSamplesPerStep,reps,randomizeOrder,save_path)
    % Type-check parameters
    if(~islogical(randomizeOrder))
        error("Ensure randomize order flag argument is of boolean/logical type");
    end 

    % Hard Coded Parameters for now
    nPrimarySteps = 10;
    nSamplesPerStep = 10;
    reps = 1; 

    
        % Which Cal file to use (currently hard-coded)
        calDir = fullfile(tbLocateProjectSilent('combiExperiments'),'cal');
        calFileName = 'CombiLED_shortLLG_testSphere_ND0x2.mat';

        cal_path = fullfile(calDir,calFileName);

        % Load the cal file
        load(cal_path,'cals');
        cal = cals{end};

        % Initialize the chip we want and the mode for it to be in
        chip = obj.chip_name_map("AMS7341");
        chip_functions = obj.chip_functions_map(chip);
        mode = chip_functions('Channels');

        % Get the number of channels it can observe
        nChannels = obj.nChannels;

        % Get the device's serial number
        deviceSerialNumber = obj.serial_number;

        disp(deviceSerialNumber);

        % Initialize combiLED light source object
        CL = CombiLEDcontrol();
        
        % Update the combiLED's gamma table
        CL.setGamma(cal.processedData.gammaTable);


        % Extract some information regarding the light source that is being used to
        % calibrate the minispect
        sourceS = cal.rawData.S;
        sourceP_abs = cal.processedData.P_device;
        nSourcePrimaries = cal.describe.displayPrimariesNum;

        % Initialize holder for measurements 
        counts = nan(reps,nPrimarySteps,nChannels,nSamplesPerStep);

        % Define combiLED settings and their order
        order_map = containers.Map({true,false},{randperm(nPrimarySteps),1:nPrimarySteps});
        setting_formula = @(ii) 0.05+((ii-1)/(nPrimarySteps-1))*0.9;
        combi_settings_sorted = arrayfun(setting_formula, 1:nPrimarySteps);
        settings_order = order_map(randomizeOrder);

        % Finalized settings
        combi_settings = combi_settings_sorted(settings_order);

        % Run through every combiLED setting
        for ii = 1:length(combi_settings)
            fprintf("Primary Step: %d / %d\n", ii, nPrimarySteps);

            % Perform desired repetitions of each setting
            for jj = 1:reps
                fprintf("Repetition: %d / %d\n", jj, reps);

                % Get the current combiLED setting
                primary_setting = combi_settings(ii);

                % Set the combiLED settings
                CL_settings = primary_setting * ones(1,8);

                % Set primaries with combiLED settings
                CL.setPrimaries(CL_settings);
      

                % Record N samples from the minispect
        
                for kk = 1:nSamplesPerStep
                    fprintf("Sample: %d / %d\n", kk, nSamplesPerStep);
                    channel_values = obj.read_minispect(chip,mode);

                    counts(jj,ii,:,kk) = channel_values;

                end
            end
        end

    % Make sure all data was read properly
    if(any(isnan(counts)))
        error('NaNs present in counts');
    end 

        MSCalData = struct; 

        raw_data = struct; 
        raw_data.counts = counts; 
        raw_data.meta.settings = combi_settings; 
        raw_data.meta.settings_order = combi_settings_sorted;

        parameters = struct; 
        parameters.NDF = NDF;
        parameters.nPrimarySteps = nPrimarySteps;
        parameters.nSamplesPerStep = nSamplesPerStep; 
        parameters.reps = reps; 
        parameters.randomizeOrder = randomizeOrder; 

        meta_data = struct; 
        meta_data.serialNumber = deviceSerialNumber;
        meta_data.cal = cal_path; 
        meta_data.params = parameters; 
        meta_data.date = datetime('now');

        MSCalData.raw = raw_data;
        MSCalData.meta = meta_data; 

        % Save the calibration results
        save(save_path,'MSCalData');

        % Close the serial ports with the external device (combiLED)
        CL.serialClose();
        clear CL;

   


end