function plot_temporal_sensitivity(results_path)
% Plot the temporal sensitivity function from measurements taken with collect_temporal_sensitivity_measurements
%
% Syntax:
%   plot_minispect_temporal_sensitivity(results_path)
%
% Description:
%  Plot the temporal sensitivity function for a given chip whose measurements 
%  were collected with collect_temporal_sensitivity_measurements. 
%
% Inputs:
%   results_path          - String. Represents the full path to a TemporalSensitivityResults.mat
%                           file.      
%
% Outputs:
%   NONE
%
% Examples:
%{
    results_path = '/Users/zacharykelly/Aguirre-Brainard Lab Dropbox/Zachary Kelly/FLIC_admin/Equipment/MiniSpect/calibration/graphs/TSL2591_TemporalSensitivtyMeasurements.mat';
    plot_minispect_temporal_sensitivity(results_path);
%}
    % Parse and validate the input arguments
    parser = inputParser; 

    parser.addRequired('results_path', @(x) ischar(x) || isstring(x)) % Ensure cal_path is a string
    
    parser.parse(results_path);

    results_path = parser.Results.results_path;

    % Construct the path to the folder in which to save the graph
    drop_box_dir = [getpref('combiExperiments','dropboxBaseDir'), '/FLIC_admin/Equipment/MiniSpect/calibration/graphs/'];
    
    
    % Load in the results of collect_temporal_sensitivity_measurements
    measurements = load(results_path).results; 

    % Retrieve the information used for plotting the TTF
    % This is a matrix with dimensions (NDF, FREQ, AMPLITUDES)
    ndf_freq_amplitudes = measurements.ndf_freq_amplitudes;
    frequencies = measurements.frequencies; 
    ndf_range = measurements.ndf_range; 
    secsPerMeasure = measurements.secsPerMeasure; 
    chip_name = measurements.chip_name; 
    channel_to_plot = 4; 

    % Open a new figure
    figure; 
    plotColors = distinguishable_colors(numel(ndf_range) + 1);
    tg = uitabgroup();

    % Plot the data we have observed
    for nn=1:numel(ndf_range) + 1
        x = 0; % Initialize x, y, and NDF variables 
        y = 0;
        NDF = 0; 

        % Set the tab axis for this plot
        tabSet{nn} = uitab(tg);
        ax = axes('Parent', tabSet{nn});


        % If out of NDF range, plot the ideal device
        if(nn > numel(ndf_range))
            NDF = 'Ideal Device';
            
            sourceFreqsHz = frequencies; 
            dTsignal = secsPerMeasure; 
            
            x = log10(frequencies);
            y = idealDiscreteSampleFilter(sourceFreqsHz,dTsignal);

            % Generate the legend label for this tab
            label = sprintf('%s', NDF);

        else 
            NDF = ndf_range(nn);

            % Format the observed data into x and y 
            x = log10(frequencies);
            y = ndf_freq_amplitudes(nn,:,channel_to_plot) / max(ndf_freq_amplitudes(nn,:,channel_to_plot)); 

            % Generate the legend label for this tab
            label = sprintf('ND%.2f', NDF);

        end

        % Plot this NDF's observed data
        scatHand(nn) = scatter(x, y, 100,'o',...
            'MarkerEdgeColor','none','MarkerFaceColor',plotColors(nn,:),...
            'MarkerFaceAlpha', .2);
        
        axis square; 
        title(sprintf('Temporal Sensitivity for Clear/FS Channel %s', label))
        xlabel('Source Frequency [log]');
        ylabel('Relative Amplitude of Response');  
        
        legend(label,'Location','northwest');

        % Save this tab to a file
        figName = fullfile(drop_box_dir, sprintf('%s_%s_TemporalSensitivity.pdf', chip_name, label));
        exportgraphics(tabSet{nn},figName);

    end

    hold off; 

end