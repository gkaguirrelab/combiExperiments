function [interpolated_signal, interpolated_signalT] = interpolateSignal(signal, signalT, fit, modelT, threshold, fps)
% Interpolate a sine wave modulation captured via the camera to fill 
% in dropped frames and improve R2

% First, plot the dropped frames and return a matrix of their start/end
% times
[timestamps, fig_handle] = plotDroppedFrames(signal, signalT, fit, modelT, threshold);

% Now, we will interpolate the dropped frames within the bounds of the gaps 

% Find the temporal support indices where it is equal to the beginning time
% stamps 
start_indices = find(ismember(signalT, timestamps(:, 1)) == true); 

% The end indices are simply one past the beginning
end_indices = start_indices + 1; 

disp('Temporal Support Indices of Potentially Dropped Frames');
disp('          Start | End');
disp([start_indices' end_indices'])

% We will use average interpolation, thus 
% find the average values between the starts and ends
average_values = (signal(start_indices) + signal(end_indices)) / 2; 

% Activate the previous figure
figure(fig_handle);

% Now, for each gap, we must plot the appropriate number of 
% points for the given FPS to simulate signal values 
for ii = 1:size(timestamps, 1)
    % Retrieve the start and end points for this 
    % specific gap
    start_t = timestamps(ii, 1);
    end_t = timestamps(ii, 2);
    
    % Generate the time values for the frames we missed 
    temporal_support_i = start_t+(1/fps):(1/fps):end_t;

    % Match those time values with the average value we calculated 
    interpolated_values_i = ones(size(temporal_support_i)) * average_values(ii); 
    
    % Append the generated values to growing containers;
    % Each row in the cell arrays represent one gaps imformation 
    temporal_support{ii} = temporal_support_i; 
    interpolated_values{ii} = interpolated_values_i; 
end

% Plot the interpolated values. Flatten the cell arrays for plotting
% purposes
plot([temporal_support{:}], [interpolated_values{:}], '.', 'Color', 'red', 'DisplayName','Interpolation');

legend show; 

% Now, we will generate the interpolated signal and signalT vectors
interpolated_signal = signal; 
interpolated_signalT = signalT; 

% Iterate over the cell array containers 
% and insert the information per gap
for ii = 1:size(temporal_support, 1);
    % Retrieve this gap's information
    gap_t = temporal_support{ii};
    gap_v = interpolated_values{ii};

    % Find the index at which this gap should be inserted
    end_idx = end_indices(ii);

    % Add the temporal support to the interpolated signalT vector 
    interpolated_signalT = [interpolated_signalT(1:end_idx), gap_t, interpolated_signalT(end_idx:end)];

    % Add this gap's values to the interpolated signal vector
    interpolated_signal = [interpolated_signal(1:end_idx), gap_v, interpolated_signal(end_idx:end)];
end
