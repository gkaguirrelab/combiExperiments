function determine_bestMSparams(cal_path)
% Serves as both a guide and documentation for finding best params for MS chips
    
    % Step 1: Connect MiniSpect and CombiLED
    MS = mini_spect_control(); % Initialize MiniSpect Object
    
    calDir = fullfile(tbLocateProjectSilent('combiExperiments'),'cal'); % Which Cal file to use (currently hard-coded)
    calFileName = 'CombiLED_shortLLG_testSphere_ND0x2.mat';

    cal_path = fullfile(calDir,calFileName);

    load(cal_path,'cals'); % Load the cal file
    cal = cals{end};
    
    CL = CombiLEDcontrol(); % Initialize CombiLED Object
    CL.setGamma(cal.processedData.gammaTable);  % Update the combiLED's gamma table
    
    upper_bound_ndf_map = containers.Map({'AMS7341','TSL2591'},{0.2,2}); % associate our desired upper bounds
    lower_bound_ndf_map = containers.Map({'AMS7341','TSL2591'},{4,6});   % associate our desired lower bounds
    
    % Step 2: Enter chip to test and get lower and upper bounds
    light_sensing_chips = ['AMS7341','TSL2591'];
    chip_name = 'AMS7341';
    chip = MS.chip_name_map(chip_name);
    chip_functions = MS.chip_functions_map(chip); % Retrieve the available functions of the given chip
    nDetectorChannels = MS.chip_nChannels_map(chip);  % Retrieve the channels the given chip can read
    
    assert(any(ismember(chip_name,light_sensing_chips) == true)); % assert chip choice is among light-sensing chips
    
    upper_bound_ndf = upper_bound_ndf_map(chip_name); % retrieve upper bound ndf for this chip
    lower_bound_ndf = lower_bound_ndf_map(chip_name); % retrieve lower bound ndf for this chip
    
    ndf_range = [lower_bound_ndf,upper_bound_ndf]; % build the range of the chip
    
    % Step 3: Prepare the CombiLED Settings to vary over 
    background = [1,1,1,1,1,1,1,1];
    background_scalars = linspace(0.05,0.95,size(background,2)); % gives equally spaced intervals between
                                                                 % low,high * a given NDF level. Alter if desired
    settings_formula = @(ii) background * background_scalars(ii); % formula for each setting ii
    combiLEDSettings = arrayfun(settings_formula, 1:numel(background_scalars), 'UniformOutput', false); % all settings

    % Step 4: Prepare the chip parameters to vary over
    integration_parameters = [[249,259,0];    % format: ATIME,ASTEP,GAIN
                              [24,599,0]];

    if(chip_name== 'AMS7341')   % error check the chip parameters
        assert(all(integration_parameters(:,1) > 0 ) && all(integration_parameters(:,1) < 2^8)); % assert ATIME in range for chip
        assert(all(integration_parameters(:,2) > 0 ) && all(integration_parameters(:,2) < 2^16)); % assert ASTEP in range for chip
        assert(all(integration_parameters(:,3) >= 0 ) && all(integration_parameters(:,3) < 11)); % assert GAIN in range  for chip
    else 
        assert(all(integration_parameters(:,1) > 0 ) && all(integration_parameters(:,1) < 6)); % assert ATIME in range for chip
        assert(all(integration_parameters(:,2) > 0 ) && all(integration_parameters(:,2) == 0)); % assert ASTEP in range for chip 
        assert(all(integration_parameters(:,3) >= 0 ) && all(integration_parameters(:,3) < 49) && all(mod(integration_parameters(:,3),16))); % assert GAIN in range  for chip
    end

    for bb = 1:size(bounds,2) % Test lower bound and upper bound
        %  Step 5: Place the low bound NDF filter onto the light source, and begin testing
        fprintf('Place %f filter onto light source. Press any key when ready\n', bounds(bb));
        pause()

        for cc = 1:size(combiLEDSettings,1) % Test all of the CombiLED settings
            % Step 6: Set current CombiLED setting
            CL_settings = combiLEDSettings{ii};
            CL.setPrimaries(CL_settings);


            measured_counts = nan(size(integration_parameters,1),nMeasurements,nDetectorChannels); % setup output data
            secsPerMeasure = nan(size(integration_parameters,1));

            for pp = 1:size(integration_parameters,1) % Test all of the different integration params
                % Step 8: Set the current integration parameters 
                atime = integration_parameters(pp,1);
                astep = integration_parameters(pp,2);
                gain = integration_parameters(pp,3); 

                mode = chip_functions('ATIME');
                MS.write_minispect(chip,mode,num2str(atime));

                mode = chip_functions('ASTEP');
                MS.write_minispect(chip,mode,num2str(astep));

                mode = chip_functions('Gain');
                MS.write_minispect(chip,mode,num2str(gain));

                % Step 9: Take nMeasurements and begin timing 
                nMeasurements = 10;
                mode = chip_functions('Channels');
                tic ; 
                for ii = 1:nMeasurements
                    channel_values = MS.read_minispect(chip,mode);

                    measured_counts(pp,ii,:) = channel_values;
                end
                elapsed_seconds = toc ; 

                secsPerMeasure(pp) = elapsed_seconds/nMeasurements;


            end
        end
    end

    return 

    % Set up arrays to store statistics
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
    MSStabilityData.meta.chip = chip; 
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