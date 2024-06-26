function corrected = correct_predictions(predictions,measurements)
    corrected = nan(size(predictions));

    % Get the ratio matrix between predictions and measurements
    K = predictions ./ measurements;

    % For each channel, perform correction by dividing 
    % the predictions by the mean scalar of that channel (since
    % there is slight variation and they are all close)
    for ii = 1:size(predictions,2)
        corrected(:,ii) = predictions(:,ii)/mean(K(:,ii));
    end

    figure 

    plot(predictions(:,1),'--r') % Plot predictions of channel 1

    hold on;
    
    plot(measurements(:,1), '--b') % Plot measurements of channel 1
    plot(corrected(:,1), '--g') % Plot the correct predictions of channel 1
    
    
    plot(predictions(:,2), '--y') % Plot predictions of channel 2
    plot(measurements(:,2), '--m') % Plot measurements of channel 2
    plot(corrected(:,2), '--k') % Plot the correct predictions of channel 2


    legend('P1', 'M1', 'C1', 'P2', 'M2','C2');

    xlabel('Primary Step');
    ylabel('Value');
    title('Corrected Predictions Compared to Measurements');

    % Get current axes handle
    ax = gca;

    % Change the background color of the axes
    ax.Color = [0.9, 0.9, 0.9];  % Light blue background

    hold off;

    % Save the figure
    saveas(gcf,'/Users/zacharykelly/Aguirre-Brainard Lab Dropbox/Zachary Kelly/FLIC_admin/Equipment/MiniSpect/calibration/corrected_predictions.jpg');