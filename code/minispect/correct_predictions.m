function corrected = correct_predictions(predictions,measurements)
    % Get the ratio matrix between predictions and measurements
    ratio_matrix = predictions ./ measurements;

    K = mean(ratio_matrix(:)); 

    figure 

    for ii = 1:8
        plot(predictions(:,ii)/K,measurements(:,ii),'.-')
        hold on
    end 



    %plot(measurements(:,1), '--b') % Plot measurements of channel 1
    %plot(corrected(:,1), '--g') % Plot the correct predictions of channel 1
    
    
    %plot(predictions(:,2), '--y') % Plot predictions of channel 2
    %plot(measurements(:,2), '--m') % Plot measurements of channel 2
    %plot(corrected(:,2), '--k') % Plot the correct predictions of channel 2

    xlabel('Fitted');
    ylabel('Measured');
    title('Ratio of Channel Measurements by Predictions');

    % Get current axes handle
    ax = gca;

    % Change the background color of the axes
    ax.Color = [0.9, 0.9, 0.9];  % Light blue background

    hold off;

    % Save the figure
    saveas(gcf,'/Users/zacharykelly/Aguirre-Brainard Lab Dropbox/Zachary Kelly/FLIC_admin/Equipment/MiniSpect/calibration/channels_fitted_by_predictions.jpg');