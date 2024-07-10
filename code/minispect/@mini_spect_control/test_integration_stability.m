function test_integration_stability(obj,NDF,cal_path,chip_fullname)
    % Ensure we have a real device connected
    if(obj.simulate)
        error('Cannot calibrate. Device in simulation mode.')
    end

    % Set the background lighting of the combiLED
    % and the scalar settings we will use
    background = [1,1,1,1,1,1,1,1];
    background_scalars = linspace(0.05,0.95,size(background,2));

    % Parameters to vary over 
    integration_parameters = [[1,0];[2,0]];
    settings_formula = @(ii) background * background_scalars(ii);
    combiLEDSettings = arrayfun(settings_formula, 1:numel(background_scalars), 'UniformOutput', false);

    % Ensure values do not cause overflow
    max_value_map = containers.Map({'AMS7341','TSL2591'},...
                                    {containers.Map({'astep', 'atime'},{2^16-1,2^8-1}),...
                                    containers.Map({'atime','astep'},{5,0})}); 

    chip_maxes = max_value_map(chip_fullname);
    max_values = [chip_maxes('atime'), chip_maxes('astep')];

    % Which Cal file to use (currently hard-coded)
    calDir = fullfile(tbLocateProjectSilent('combiExperiments'),'cal');
    calFileName = 'CombiLED_shortLLG_testSphere_ND0x2.mat';

    cal_path = fullfile(calDir,calFileName);

    % Load the cal file
    load(cal_path,'cals');
    cal = cals{end};
    
    % Initialize combiLED light source object
    CL = CombiLEDcontrol();

    % Update the combiLED's gamma table
    CL.setGamma(cal.processedData.gammaTable);

    % Retrieve the underlying representation of the 
    % chip on the minispect and its available 
    % functions
    chip = obj.chip_name_map(chip_fullname);
    chip_functions = obj.chip_functions_map(chip);

    % The AS chip lets us modify both ATIME and ASTEP, 
    % but the TS chip only lets us modify integration time,
    % so arbitrarily choose ATIME to represent this
    available_fields_map = containers.Map({'A','T'},{{'ATIME','ASTEP'},{'ATIME'}});
    
    % Set the integration parameters of the chip on the minispect
    variables_to_modify = available_fields_map(chip);
    
    % Retrieve the channels the given chip can read 
    nDetectorChannels = obj.chip_nChannels_map(chip);
    
    % Set up arrays to store statistics
    measured_counts = nan(size(combiLEDSettings,1), size(integration_parameters,1), nDetectorChannels);
    secsPerMeasure = nan(size(combiLEDSettings,1),size(integration_parameters,1));
    means = nan(size(combiLEDSettings,1), nDetectorChannels); 
    stds = nan(size(combiLEDSettings,1), nDetectorChannels); 
    absolute_ranges = nan(nDetectorChannels,2);
    linearity = nan(nDetectorChannels);

    % Iterate over the different combiLED settings
    for ii = 1:numel(combiLEDSettings)
        fprintf("CombiLED Setting %d / %d", ii, numel(combiLEDSettings))
        % Retrieve the current combiLED settings
        CL_settings = combiLEDSettings{ii};

        disp(CL_settings);
        % Set primaries with combiLED settings
        CL.setPrimaries(CL_settings);

        % Vary the integration time at a given setting
        for jj = 1:size(integration_parameters,1)
            fprintf("Integration Parameters: %d / %d\n",jj,size(integration_parameters,1));

            disp(variables_to_modify);
            disp(integration_parameters(jj,:));
      
            for aa = 1:numel(variables_to_modify)
                mode = chip_functions(variables_to_modify{aa});

                % Ensure parameter is in the appropriate range
                % for the field
                assert(integration_parameters(jj,aa) <= max_values(1,aa))

                write_val = num2str(integration_parameters(jj,aa));
                obj.write_minispect(chip,mode,write_val);
            end

            % Start timer
            tic; 
            
            % Read the channels from the chip on the minispect
            mode = chip_functions('Channels');
            channel_values = obj.read_minispect(chip,mode);

            % Calculate the real elapsed time for a measurement
            elapsed_time = toc; 
            
            % Save the information for this combination of combiLEDSettings
            % and integration parameters
            measured_counts(ii,jj,:) = channel_values; 
            secsPerMeasure(ii,jj) = elapsed_time;
        end 

        % Calculate settings level statistics 
        for cc = 1:nDetectorChannels
            % Find the standard deviation and mean of a channel 
            stds(ii,cc) = std(measured_counts(ii,:,cc)); 
            means(ii,cc) = mean(measured_counts(ii,:,cc)); 
        end
    end

    % Calculate global statistics about the experiment
    % for each channel
    for cc = 1:nDetectorChannels
        all_channel_readings = measured_counts(:,:,cc);
        absolute_ranges(cc,1) = min(all_channel_readings(:));
        absolute_ranges(cc,2) = max(all_channel_readings(:));
 
        % Find the linearity of a channel across 
        % combiLED settings, just using the first 
        % integration parameter for now
        y = squeeze(measured_counts(:, 1, cc));
        linear_model = fitlm(1:numel(combiLEDSettings), y);
        linearity(cc) = linear_model.Rsquared.Ordinary;
    end
    
    % Store Meta Data Information 
    MSStabilityData.meta.chip = chip_fullname; 
    MSStabilityData.meta.NDF = NDF;
    MSStabilityData.meta.cal_path = cal_path; 
    MSStabilityData.meta.cal = cal; 
    MSStabilityData.meta.nDetectorChannels = nDetectorChannels;
    MSStabilityData.meta.background = background; 
    MSStabilityData.meta.background_scalars = background_scalars;
    
    % Store Raw Measurement information
    MSStabilityData.raw.measured_counts = measured_counts;
    MSStabilityData.raw.secsPerMeasure = secsPerMeasure;
    MSStabilityData.raw.means = means;
    MSStabilityData.raw.stds = stds;
    MSStabilityData.raw.absolute_ranges = absolute_ranges;
    MSStabilityData.raw.linearity = linearity;

    save('MSStabilityData.mat','MSStabilityData');

end