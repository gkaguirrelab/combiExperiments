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
    results_path = '';
    plot_temporal_sensitivity(results_path);
%}

    % Load in the results of collect_temporal_sensitivity_measurements
    measurements = load(results_path); 

    % Retrieve the information used for plotting the TTF
    % This is a matrix with dimensions (NDF, FREQ, AMPLITUDES)
    ndf_freq_amplitudes = measurements.ndf_freq_amplitudes;
    frequencies = measurements.frequencies; 
    ndf_range = measurements.ndf_range; 

    % Create the figure used for plotting
    figure ; 
    tg = uitabgroup();

    tabSet{cc} = uitab(tg);
    ax1 = axes('Parent', tabSet{cc});


    x = frequencies; % First, plot the low bound results' amplitude (normalized)
    y = ndf_freq_amplitudes(1,:,channel_to_plot) / max(ndf_freq_amplitudes(1,:,channel_to_plot)); 
    plot(log10(x),y,'*-');

    x = frequencies; % Then, plot the high bound results' amplitude (normalized)
    y = ndf_freq_amplitudes(2,:,channel_to_plot) / max(ndf_freq_amplitudes(2,:,channel_to_plot)); 
    plot(log10(x),y,'*-');

    sourceFreqsHz = frequencies; % Then, plot the "ideal device"
    dTsignal = secsPerMeasure; 
    
    x = frequencies;
    y = idealDiscreteSampleFilter(sourceFreqsHz,dTsignal);
    plot(log10(x),y,'-');

    xlabel('Source Frequency [log]');   
    ylabel('Relative amplitude of response');
    title('Temporal Sensitivity for Clear/FS Channel');
    legend(sprintf('%.1f NDF', lower_bound_ndf), sprintf('%.1f NDF', upper_bound_ndf), 'Ideal Device');
    hold off; 



end