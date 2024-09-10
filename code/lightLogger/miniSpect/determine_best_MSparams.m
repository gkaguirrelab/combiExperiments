function determine_best_MSparams(cal_path,chip_name)
% Serves as both a guide and documentation for finding best params for MS chips
%
% Syntax:
%   determine_best_MSparams(cal_path,chip_name)
%
% Description:
%  Tests sets of parameters for a given light-sensing chip in the MiniSpect
%  at the low and high light levels. Therein, tests different percentages 
%  of the light level. Plots 2 graphs displaying the counts at the different 
%  percentages of each light level, as well as the STD of the counts, and the 
%  average time to make an individual measurement a
%
% Inputs:
%   cal_path              - String. Represents the path to the light source
%                           calibration file.      
%
%   chip_name             - String. Represents the full name of the light-sensing
%                           chip to use for the experiment          
%
% Outputs:
%   NONE
%
% Examples:
%{
   chip_name = 'AMS7341';
   cal_path = './cal';
   determine_best_MSparams(cal_path,chip_name);
%}
    
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
    chip = MS.chip_name_map(chip_name);
    chip_functions = MS.chip_functions_map(chip); % Retrieve the available functions of the given chip
    nDetectorChannels = MS.chip_nChannels_map(chip);  % Retrieve the channels the given chip can read
    usable_modes_map = containers.Map({'A','T'},{{'ATIME','ASTEP','Gain'},{'ATIME'}});
    usable_modes = usable_modes_map(chip);
    
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
    integration_parameters = [[249,259,5];  % format: ATIME,ASTEP,GAIN
                              [249,259,3];   % PARAM 1: Our chosen parameters PARAM 4: Factory recommended parameters
                              [249,259,8];          
                              [24,599,4];   
                              [24,599,2];
                              [24,599,8]];                            


    if(chip_name== 'AMS7341')   % error check the chip parameters
        assert(all(integration_parameters(:,1) > 0 ) && all(integration_parameters(:,1) < 2^8)); % assert ATIME in range for chip
        assert(all(integration_parameters(:,2) > 0 ) && all(integration_parameters(:,2) < 2^16)); % assert ASTEP in range for chip
        assert(all(integration_parameters(:,3) >= 0 ) && all(integration_parameters(:,3) < 11)); % assert GAIN in range  for chip
    else 
        assert(all(integration_parameters(:,1) >= 0 ) && all(integration_parameters(:,1) < 6)); % assert ATIME in range for chip
        assert(all(integration_parameters(:,2) == 0 )); % assert ASTEP in range for chip 
        assert(all(integration_parameters(:,3) >= 0 ) && all(integration_parameters(:,3) < 49) && all(mod(integration_parameters(:,3),16) == 0)); % assert GAIN in range  for chip
    end

    % Step 5: Determine number of measurements 
    % to take at each integration setting
    nMeasurements = 10;
    for bb = 1:size(ndf_range,2) % Test lower bound and upper bound
        NDF = ndf_range(bb);

        %  Step 6: Place the current bound NDF filter onto the light source, and begin testing
        fprintf('Place %.1f filter onto light source. Press any key when ready\n', NDF);
        pause()

        bound_counts = nan(numel(combiLEDSettings),size(integration_parameters,1),nMeasurements,nDetectorChannels);
        bound_timings = nan(numel(combiLEDSettings),size(integration_parameters,1));

        for cc = 1:numel(combiLEDSettings) % Test all of the CombiLED settings
            fprintf("CombiLED Setting %d / %d\n", cc, numel(combiLEDSettings));
            % Step 7: Set current CombiLED setting
            CL_settings = combiLEDSettings{cc};
            CL.setPrimaries(CL_settings);

            measured_counts = nan(size(integration_parameters,1),nMeasurements,nDetectorChannels); % setup output data
            secsPerMeasure = nan(size(integration_parameters,1),1);

            for pp = 1:size(integration_parameters,1) % Test all of the different integration params
                fprintf("Integration Params %d / %d\n", pp, size(integration_parameters,1));
                % Step 8: Set the current integration parameters 

                for mm = 1:size(usable_modes)
                    mode = chip_functions(usable_modes{mm});
                    MS.write_minispect(chip,mode,num2str( integration_parameters(pp,mm)  ));
                    ret = MS.read_minispect(chip,mode);
    
                    assert(str2num(ret) == integration_parameters(pp,mm)); % Ensure value was set properly
                end

                % Step 9: Take nMeasurements and time them
                mode = chip_functions('Channels');
                tic ; 
                for ii = 1:nMeasurements
                    channel_values = MS.read_minispect(chip,mode);

                    measured_counts(pp,ii,:) = channel_values;
                end
                elapsed_seconds = toc ; 

                secsPerMeasure(pp) = elapsed_seconds/nMeasurements;
            end

            % Step 10: Save results for this Combi Setting + set of integration params
            bound_counts(cc,:,:,:) = measured_counts;
            bound_timings(cc,:) = secsPerMeasure;
        end
        
        % Step 11: Plot Findings
        mean_counts = squeeze(mean(bound_counts,3));
        std_counts = squeeze(std(bound_counts,0,3));

        figure; 
        t = tiledlayout(3,size(integration_parameters,1)); % Layout is number of things we want to plot, by the integration parameters
        
        param_set_annotation = "";    
        for pp = 1:size(integration_parameters,1)  % First, plot means
            nexttile;

            param_set_annotation = param_set_annotation + sprintf('Col: %d: ATIME: %d ASTEP: %d GAIN: %d| ', pp,integration_parameters(pp,1),integration_parameters(pp,2),integration_parameters(pp,3));

            x = background_scalars;
            for kk = 1:nDetectorChannels
                y = mean_counts(:,pp,kk);

                plot(x,y);
                hold on; 

            end

            xlabel('Primary Setting');
            ylabel('Mean Count');
            title(sprintf('Mean/Set %d', pp))
            hold off; 

        end

        sgtitle(param_set_annotation); % Add param set explaination 
        for pp = 1:size(integration_parameters,1) % Then, plot the STDs
            nexttile;

            x = background_scalars;

            for kk = 1:nDetectorChannels
                y = std_counts(:,pp,kk);

                plot(x,y);
                hold on; 

            end

            xlabel('Primary Setting');
            ylabel('Standard Deviation of Counts');
            title(sprintf('STD/Set %d', pp))
            hold off; 

        end

        for pp = 1:size(integration_parameters,1) % Then, plot the time to measure
            nexttile;

            x = background_scalars;
            ylim([0,0.75]);
            for kk = 1:nDetectorChannels
                y = bound_timings(:,pp);

                plot(x,y,'LineWidth',3);
                hold on; 

            end

            xlabel('Primary Setting');
            ylabel('Seconds Per Measure');
            title(sprintf('Time/Set %d', pp))
            hold off; 

        end

        ymax = 0;
        for ii = 1:size(integration_parameters,1) % Set graphs on row 1 to have same range/start at 0 
            h = nexttile(ii);
            ymax = max([ymax, max(ylim(h))]); 

        end

        for ii = 1:size(integration_parameters,1) %Set graphs on row 1 to have same range/start at 0 
            h = nexttile(ii);
            ylim(h,[0,ymax])
        end

        ymax = 0;
        for ii = 1*size(integration_parameters,1)+1:2*size(integration_parameters,1) % Set graphs on row 2 to have same range/start at 0 
            h = nexttile(ii);
            ymax = max([ymax, max(ylim(h))]); 
        end

        for ii = 1*size(integration_parameters,1)+1:2*size(integration_parameters,1)% Set graphs on row 2 to have same range/start at 0 
            h = nexttile(ii);
            ylim(h,[0,ymax])
        end

        ymax = 1;
        %for ii = 2*size(integration_parameters,1)+1:3*size(integration_parameters,1) % Set graphs on row 1 to have same range/start at 0 
        %    h = nexttile(ii);
        %    ymax = max([ymax, max(ylim(h))]); 
        %end

        for ii = 2*size(integration_parameters,1)+1:3*size(integration_parameters,1)% Set graphs on row 3 to have same range/start at 0 
            h = nexttile(ii);
            ylim(h,[0,ymax])
        end


        % Step 12: Save graphs, if desired
        low_high_name_map = containers.Map({1,2},{'low','high'});
        save_or_not = input('Save figure? (y/n)', 's');
        drop_box_dir = [getpref('combiExperiments','dropboxBaseDir'), '/FLIC_admin/Equipment/MiniSpect/calibration/graphs/'];
        if(save_or_not(1) == 'y')
            saveas(gcf, sprintf('%s%s_boundParamComparison.png',drop_box_dir,low_high_name_map(bb)));
        end 



    end

    % These graphs should illustrate that the params we chose for ATIME, ASTEP, and Gain 
    % allow the chips to have the best dynamic range in their respective bounds as opposed 
    % to other settings.

end