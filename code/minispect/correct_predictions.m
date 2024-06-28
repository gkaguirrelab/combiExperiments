function corrected = correct_predictions(predictions,measurements)
    % Get the ratio matrix between predictions and measurements
    ratio_matrix = predictions ./ measurements;
    
    figure 

    for ii = 1:9
        K = mean(ratio_matrix(:,ii));
        disp(predictions(:,ii)/K)
        plot(predictions(:,ii)/K,measurements(:,ii),'.-')
        hold on
    end 

    % THIS WAS THE PROBLEM
    %xlim([0, 2^16]);

    axis equal; 
    refline(1,0);

    % Set the x-axis to logarithmic scale
    set(gca, 'XScale', 'log');

    % Set the y-axis to logarithmic scale
    set(gca, 'YScale', 'log');

    legend('Channel1','Channel2','Channel3',...
           'Channel4', 'Channel5', 'Channel6', 'Channel7',...
           'Channel8', 'CLEAR', 'Location','southeast');

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
    saveas(gcf,'~/Aguirre-Brainard Lab Dropbox/Zachary Kelly/FLIC_admin/Equipment/MiniSpect/calibration/channels_fitted_by_predictions.jpg');
