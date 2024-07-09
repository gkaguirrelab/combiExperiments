function test_integration_stability(obj,NDF,cal_path,chip_fullname)
    % Ensure we have a real device connected
    if(obj.simulate)
        error('Cannot calibrate. Device in simulation mode.')
    end

    background = [1,1,1,1,1,1,1,1];
    background_scalars = linspace(0.05,0.95,size(background,2));

    % Parameters to vary over 
    integration_parameters = [[249,249]];
    settings_formula = @(ii) background * background_scalars(ii);
    combiLEDSettings = arrayfun(settings_formula, 1:numel(background_scalars), 'UniformOutput', false);

    % Ensure values do not cause overflow
    max_value_map = containers.Map({'AMS7341','TSL2591'},...
                                    {containers.Map({'astep', 'atime'},{2^16-1,2^8-1}),...
                                    containers.Map({'atime'},{5})}); 

    chip_maxes = max_value_map(chip_fullname);
    chip_max_astep = chip_maxes('astep');
    chip_max_atime = chip_maxes('atime');

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
    % and set up and array to store its counts
    nDetectorChannels = obj.chip_nChannels_map(chip);
    measured_counts = nan(size(combiLEDSettings,1), size(integration_parameters,1), nDetectorChannels);
    secsPerMeasure = nan(size(combiLEDSettings,1),size(integration_parameters,1)); 
    stds = nan(size(combiLEDSettings,1), nDetectorChannels); 
    absolute_ranges = nan(nDetectorChannels);
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
            fprintf("Integration Parameters: %d / %d",jj,size(integration_parameters,1));

            disp("Setting integration parameters");
            fprintf("%s | %s\n", variables_to_modify{1},variables_to_modify{2});
            disp(integration_parameters(jj,:));
      
            for aa = 1:numel(variables_to_modify)
                mode = chip_functions(variables_to_modify{aa});
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

        for cc = 1:nDetectorChannels
            %stds(ii,cc) = std(measured_counts(ii,:,cc)); 
        end

    end


    % Measure linearity of channel measurements across 
    % setting levels
    for cc = 1:nDetectorChannels
        x = [ones(1:size(combiLEDSettings))' ,(1:size(combiLEDSettings))' ];
        y = zeros(1:size(combiLEDSettings));

        %l = x \ y; 

        %y_fit = X * b;

        % Calculate the R-squared value (if it is completely linear should be 1)
        %y_mean = mean(y);
        %SS_total = sum((y - y_mean).^2);
        %SS_residual = sum((y - y_fit).^2);
        %R_squared = 1 - (SS_residual / SS_total);

    end

end