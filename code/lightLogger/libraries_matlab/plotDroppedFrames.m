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

    % Retrieve the y coordinates of those points
    flagged_indices_markers = signal(flagged_indices);

    % Now, plot the signal vs fit with potential drop frames highlighted
    figure; 
    plot(signalT, signal, 'x', 'Color', 'blue');
    hold on; 
    plot(modelT, fit, 'x', 'Color', 'black');
    plot(signalT(flagged_indices), flagged_indices_markers, 'o', 'Color', 'magenta');

    % Label the plot
    title('Measured vs Fit with Possible Dropped Frames');
    ylabel('Contrast');
    xlabel('Time [seconds]');
    legend('Signal', 'Fit', 'Possible Dropped Frames'); 
    

end