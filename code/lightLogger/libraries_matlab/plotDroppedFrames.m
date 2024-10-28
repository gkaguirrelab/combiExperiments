function [timestamps, fig_handle] = plotDroppedFrames(signal, signalT, fit, modelT, threshold)
% Plots a signal, its fit, and highlights potentially dropped frames in the signal
%
% Syntax:
%   plotDroppedFrames(signal, signalT, fit, modelT, threshold)
%
% Description:
%   Plots a signal and the fit of the signal, while also highlighting 
%   potentially dropped frames that may have negatively affected the 
%   fitting procedure. 
%
%
% Inputs:
%   signal                - Vector. A one dimensional vector 
%                           representing the signal to analyze
%
%   signalT               - Vector. The temporal support of the signal 
%                           vector.
%
%   fit                   - Vector. A one dimensional vector representing
%                           the curve fitting the signal. 
%
%   modelT                 - Vector. The temporal support of the fit. 
%
%   threshold             - Double. The value above which the derivative
%                           of the signal will be considered anomalous.  
%
% Outputs:
%
%   NONE
%
% Examples:
%{
    signal = [1,2,5,6,7,10,11,12,19];
    signal = [1,2,3,4,5,6,7,8,9];
    fit = [1,2,3,4,5,6,7,8,9];
    modelT = [1,2,3,4,5,6,7,8,9];
    threshold = prctile(abs(diff(signal)), 99); 
    plotDroppedFrames(signal, signalT, fit, modelT, threshold);
%}

    % Validate the arguments with respect to type and assign default values
    arguments 
        signal {mustBeVector};
        signalT {mustBeVector};
        fit {mustBeVector};
        modelT {mustBeVector};
        threshold (1,1) {mustBeNumeric} = prctile(abs(diff(signal)), 98);
    end
    

    % First, find the indices of flagged dropped frames
    flagged_indices = findDroppedFrames(signal, threshold); 

    % Retrieve the X coordinates (in seconds) where the drop frames 
    % occured
    flagged_indices_start_times = signalT(flagged_indices);
    flagged_indices_end_times = signalT(flagged_indices + 1); 

    % Retrieve the y coordinates of those points
    flagged_indices_start_markers = signal(flagged_indices);
    flagged_indices_end_markers = signal(flagged_indices + 1);
    
    % Interleave the vectors for plotting purposes
    dropped_frames_t = reshape([flagged_indices_start_times; flagged_indices_end_times], 1, [])
    dropped_frames_markers = reshape([flagged_indices_start_markers; flagged_indices_end_markers], 1, [])

    % Create a matrix with columns start time | end time 
    % of the potentially dropped frames
    timestamps = [flagged_indices_start_times' flagged_indices_end_times'];

    % Now, plot the signal vs fit with potential drop frames highlighted
    fig_handle = figure; 
    plot(signalT, signal, 'x', 'Color', 'blue', 'DisplayName', 'Signal');
    hold on; 
    plot(modelT, fit, 'x', 'Color', 'black', 'DisplayName', 'Fit');
    plot(dropped_frames_t, dropped_frames_markers, 'o', 'Color', 'magenta', 'DisplayName', 'Dropped Frames Begin/End');

    % Label the plot
    title('Measured vs Fit with Possible Dropped Frames');
    ylabel('Contrast');
    xlabel('Time [seconds]');
    legend show; 

    % Output helpful information telling the user the timepoints 
    % the possible frame drops occured 
    disp('Timestamps of Potentially Dropped Frames');
    disp('     Start | End');
    disp(timestamps);


end