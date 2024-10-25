function plotDroppedFrames(signal, signalT, fit, modelT, threshold)
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

    % Now, plot the signal vs fit with potential drop frames highlighted
    figure; 
    plot(signalT, signal, 'x', 'Color', 'blue');
    hold on; 
    plot(modelT, fit, 'x', 'Color', 'black');
    plot(flagged_indices_start_times, flagged_indices_start_markers, 'o', 'Color', 'magenta');
    plot(flagged_indices_end_times, flagged_indices_end_markers, 'o', 'Color', 'magenta');

    % Label the plot
    title('Measured vs Fit with Possible Dropped Frames');
    ylabel('Contrast');
    xlabel('Time [seconds]');
    legend('Signal', 'Fit', 'Dropped Frames Begin/End'); 
    
    % Output helpful information telling the user the timepoints 
    % the possible frame drops occured 
    disp('Timestamps of potentially dropped frames');
    disp('     Start | End');
    disp([flagged_indices_start_times' flagged_indices_end_times']);


end