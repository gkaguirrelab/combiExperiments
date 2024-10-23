function plotDroppedFrames(signal, signalT, fit, modelT, threshold)
    arguments 
        signal {mustBeVector};
        signalT {mustBeVector};
        fit {mustBeVector};
        modelT {mustBeVector};
        threshold (1,1) {mustBeNumeric} = prctile(signal, 98);
    end
    

    % First, find the indices of flagged dropped frames
    flagged_indices = findDroppedFrames(signal, threshold); 

    % Retrieve the X coordinates (in seconds) where the drop frames 
    % occured
    flagged_indices_times = signalT(flagged_indices);

    % Retrieve the y coordinates of those points
    flagged_indices_markers = signal(flagged_indices);

    % Now, plot the signal vs fit with potential drop frames highlighted
    figure; 
    plot(signalT, signal, 'x', 'Color', 'blue');
    hold on; 
    plot(modelT, fit, 'x', 'Color', 'black');
    plot(flagged_indices_times, flagged_indices_markers, 'o', 'Color', 'magenta');

    % Label the plot
    title('Measured vs Fit with Possible Dropped Frames');
    ylabel('Contrast');
    xlabel('Time [seconds]');
    legend('Signal', 'Fit', 'Possible Dropped Frames'); 
    
    % Output helpful information telling the user the timepoints 
    % the possible frame drops occured 
    disp('Timestamps of potentially dropped frames');
    disp(flagged_indices_times);


end