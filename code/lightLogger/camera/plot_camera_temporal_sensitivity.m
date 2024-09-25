function plot_camera_temporal_sensitivity(TTF_info_path)
% Plot the TTF of the camera from the recordings made with collect_camera_temporal_sensitivity_measurements. 
%
% Syntax:
%   plot_camera_temporal_sensitivty(recordings_dir, experiment_filename)
%
% Description:
%   Generates a temporal sensitivity plot of the camera using data 
%   from a given TTF_info struct. 
%
% Inputs:
%   TTF_info_path        - String. Represents the path to a TTF_info struct  
%
% Outputs:
%   NONE
%
% Examples:
%{
    TTF_info_path = '/Users/zacharykelly/Aguirre-Brainard Lab Dropbox/Zachary Kelly/FLIC_admin/Equipment/SpectacleCamera/calibration/graphs/TTF_info.mat'; 
    plot_camera_temporal_sensitivity(TTF_info_path);
%}
    % Parse and validate the inputs 
    parser = inputParser;
    parser.addRequired("TTF_info_path", @(x) ischar(x) || isstring(x)); % Ensure the TTF_info_path is a string type 
    parser.parse(TTF_info_path);

    TTF_info_path = parser.Results.TTF_info_path; 

    % Read in the TTF info 
    TTF_info = load(TTF_info_path).TTF_info; 

    % Retrieve some basic information first 
    CAM_FPS = TTF_info.fixed_FPS; 
    ideal_device_curve_xy = TTF_info.ideal_device; 

    % Retrieve the fieldnames
    field_names = fieldnames(TTF_info);

    % Initialize containers to hold the amplitudes 
    % by frequency and NDF level
    ndf_freq_amplitudes = containers.Map();
    ndf_warmup_settings = containers.Map();

    % First, we are going to plot the TTF and the obsevred FPS 
    % per NDF per frequency

    % Iterate across the NDF levels
    for fn = 1:numel(field_names)
        field_name = field_names{fn};

        % If the field is not an NDF field, simply skip
        if(~contains(field_name, 'ND'))
            continue; 
        end 

        % Retrieve the numeric NDF level representation
        NDF_level = str2ndf(field_name(3:end));

        % Otherwise, explore this NDF level's information 
        nd_struct = TTF_info.(field_name);

        % Retrieve the frequencies shown to the camera 
        frequencies_as_str = cellfun(@(x) x(2:end), fieldnames(nd_struct.fits), 'UniformOutput', false); % Splice out the first initial F character from frequency
        frequencies = cellfun(@str2ndf, frequencies_as_str); % Convert the string frequencies to their numeric representations

        % Retrieve the corrected amplitudes for this ND level
        corrected_amplitudes = nd_struct.corrected_amplitudes;

        % Retrieve the fit FPS values for each frequency for this ND level
        fit_fps = nd_struct.videos_fps; 

        % Retrieve the warmup settings for this NDF level (just choose the first frequency for this)
        warmup_t = nd_struct.warmup_t;
        warmup_settings = nd_struct.warmup_settings{1}

        % Save this NDF value and its associated amplitudes 
        ndf_freq_amplitudes(field_name) = {NDF_level, frequencies, corrected_amplitudes, fit_fps};

        % Save this NDF value and its associated warmup settings
        ndf_warmup_settings(field_name) = {NDF_level, warmup_t, warmup_settings};
    end 

    % Plot the temporal transfer function
    figure ; 
    tg = uitabgroup();

    % First retrieve the keys of the mapping between ND level and values
    NDF_levels_as_str = keys(ndf_freq_amplitudes);
    tabIndex = 1;

    % Iterate over them 
    for kk = 1:numel(NDF_levels_as_str)
        % Set the tab for this NDF level
        tabSet{tabIndex} = uitab(tg);
        ax = axes('Parent', tabSet{tabIndex});

        % Retrieve the key value for this ND's info
        nd_key = NDF_levels_as_str{kk};

        % Retrieve the info for this ND level
        nd_info = ndf_freq_amplitudes(nd_key);
        nd_warmup_info = ndf_warmup_settings(nd_key);

        % Retrieve the NDF level, frequencies, and corrected amplitudes
        NDF_level = nd_info{1};
        frequencies = nd_info{2};
        amplitudes = nd_info{3};
        fit_fps = nd_info{4};

        % Retrieve the warmup temporal support and values 
        warmup_t = nd_warmup_info{2};
        warmup_settings = nd_warmup_info{3};
        
        fprintf('Plotting %f NDF\n', NDF_level);
        
        % Plot the amplitudes by log frequencies
        plot(log10(frequencies), amplitudes);

        % Label the graph
        title(sprintf('Temporal Sensitivity: %s', nd_key))
        xlabel('Source Frequency [log]');
        ylabel('Relative Amplitude of Response');  
        legend(nd_key,'Location','northwest');

        % Now plot this ND's associated FPS
        tabSet{tabIndex+1} = uitab(tg);
        ax = axes('Parent', tabSet{tabIndex+1});

        % Plot the amplitudes by log frequencies
        plot(log10(frequencies), fit_fps);

        % Label the graph
        title(sprintf('Fit FPS by Frequency %s', nd_key))
        xlabel('Source Frequency [log]');
        ylabel('Fit FPS');  
        legend(nd_key,'Location','northwest');
 

        % Now plot the warmup settings for this NDF level
        % Plot the warmup settings (should be dual axis plot)
        tabSet{tabIndex+2} = uitab(tg);
        ax = axes('Parent', tabSet{tabIndex+2});

        yyaxis left  % Activate the left y-axis
        plot(warmup_t, warmup_settings.gain_history) % Plot the gain history 
        ylabel('Gain');  

        yyaxis right  % Activate the right y-axis
        plot(warmup_t, warmup_settings.exposure_history) % Plot the exposure history
        ylabel('Exposure time [μs]');  

        % Label the graph
        title(sprintf('Warmup Settings %s', nd_key))
        xlabel('Time [seconds]');

        % Increment the next set of plots
        tabIndex = tabIndex + 3; 

    end 

    % Now plot the ideal device curve
    tabSet{tabIndex} = uitab(tg);
    ax = axes('Parent', tabSet{tabIndex});

    fprintf('Plotting ideal device onto the TTF\n', NDF_level);

    % Plot the ideal device curve 
    plot(log10(ideal_device_curve_xy{1}), ideal_device_curve_xy{2});

    % Label the graph
    title(sprintf('Temporal Sensitivity: Ideal Device'))
    xlabel('Source Frequency [log]');
    ylabel('Relative Amplitude of Response');  
    
    legend('Ideal Device','Location','northwest');

    hold off ; 

    % Now, we are going to plot the warm up settings
    figure ; 
    tg = uitabgroup();

    % Iterate over the NDF levels
    for kk = 1:numel(NDF_levels_as_str)
        % Set the tab for this NDF level
        tabSet{kk} = uitab(tg);
        ax = axes('Parent', tabSet{kk});

        % Retrieve the key value for this ND's info
        nd_key = NDF_levels_as_str{kk};

        % Retrieve the info for this ND level
        nd_info = ndf_freq_amplitudes(nd_key);

        % Retrieve the NDF level, frequencies, and corrected amplitudes
        NDF_level = nd_info{1};



    end




end