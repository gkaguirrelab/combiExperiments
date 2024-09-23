function plot_temporal_sensitivity(results_path)
% Plot the temporal sensitivity function from measurements taken with collect_temporal_sensitivity_measurements
%
% Syntax:
%   plot_temporal_sensitivity(results_path)
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
    plot_temporal_sensitivity(results_path);
%}

    % Load in the results of collect_temporal_sensitivity_measurements
    measurements = load(results_path).results; 

    % Retrieve the information used for plotting the TTF
    % This is a matrix with dimensions (NDF, FREQ, AMPLITUDES)
    ndf_freq_amplitudes = measurements.ndf_freq_amplitudes;
    frequencies = measurements.frequencies; 
    ndf_range = measurements.ndf_range; 
    secsPerMeasure = measurements.secsPerMeasure; 
    chip_name = measurements.chip_name; 
    channel_to_plot = 1; 

    figure ; 
    hold on ; 

    % First, plot the low bound results' amplitude (normalized)
    x = frequencies;
    y = ndf_freq_amplitudes(1,:,channel_to_plot) / max(ndf_freq_amplitudes(1,:,channel_to_plot)); 
    plot(log10(x),y,'*-');

    % Then, plot the high bound results' amplitude (normalized)
    x = frequencies;
    y = ndf_freq_amplitudes(2,:,channel_to_plot) / max(ndf_freq_amplitudes(2,:,channel_to_plot)); 
    plot(log10(x),y,'*-');

    % Then, plot the "ideal device"
    sourceFreqsHz = frequencies; 
    dTsignal = secsPerMeasure; 
    
    x = frequencies;
    y = idealDiscreteSampleFilter(sourceFreqsHz,dTsignal);
    plot(log10(x),y,'-');

    % Label the graph
    xlabel('Source Frequency [log]');   
    ylabel('Relative amplitude of response');
    title('Temporal Sensitivity for Clear/FS Channel');
    legend(sprintf('%.1f NDF', ndf_range(1)), sprintf('%.1f NDF', ndf_range(2)), 'Ideal Device');

    % Save the graph in dropbox
    drop_box_dir = [getpref('combiExperiments','dropboxBaseDir'), '/FLIC_admin/Equipment/MiniSpect/calibration/graphs/'];
    saveas(gcf, sprintf('%s%s_TemporalSensitivity.pdf', drop_box_dir, chip_name));


end