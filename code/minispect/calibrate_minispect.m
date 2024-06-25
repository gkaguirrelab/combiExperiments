% Parameters
nPrimarySteps = 3; 
nSamplesPerStep = 3;

calFileName = 'CombiLED_shortLLG_testSphere_ND0x2.mat';
calDir = '/Users/zacharykelly/Documents/MATLAB/projects/combiExperiments/cal';
load(fullfile(calDir,calFileName),'cals');
cal = cals{end};

% Initialize combiLED object
CL = CombiLEDcontrol();

% Update the gamma table
CL.setGamma(cal.processedData.gammaTable);

% Initialize minispect object
MS = mini_spect_control();

% Initialize the chip we want and the mode for it to be in
chip = MS.chip_name_map("ASM7341");
chip_functions = MS.chip_functions_map(chip);
mode = chip_functions('Channels');

% Arrays to hold outputs over time series
combi_intensities = zeros(1,nPrimarySteps);
means = zeros(nPrimarySteps,10);
standard_deviations = zeros(nPrimarySteps,10);


for i = 1:nPrimarySteps
    % The intensity of every channel of the CL at this timestep
    channel_intensity = 0.05+((i-1)/(nPrimarySteps-1))*0.9;
    combi_intensities(1,i) = channel_intensity;

    % Set the CombiLED settings
    CL_settings = channel_intensity * ones(1,8);
    CL.setPrimaries(CL_settings);
    
    % Initialize matrix where Row_i = sample_i, col_i = channel_i 
    channel_readings_matrix = zeros(nSamplesPerStep,10);
    
    % get the mean and std of each col (channel) over this matrix at 
    % this Primary step. We are going to plot all of these later by primary step 

    % Record N samples from the minispect
    for j = 1:nSamplesPerStep
        channel_values = MS.read_minispect(chip,mode); 

        channel_readings_matrix(j,:) = channel_values; 
    end

    disp(channel_readings_matrix)

    % Calculate and save the means/STD of each channel
    means(i,:) = mean(channel_readings_matrix);
    standard_deviations(i,:) = std(channel_readings_matrix);


end


% Create the line graph of mean by intensity for every channel
figure; 

plot(combi_intensities(1,:), means(:,1), '--r') % Plot Channel 1

hold on;
plot(combi_intensities(1,:), means(:,2), '--b') % Plot Channel 2
plot(combi_intensities(1,:), means(:,3), '--g') % Plot Channel 3
plot(combi_intensities(1,:), means(:,4), '--m') % Plot Channel 4
plot(combi_intensities(1,:), means(:,5), '--y') % Plot Channel 5
plot(combi_intensities(1,:), means(:,6), '--k') % Plot Channel 6
plot(combi_intensities(1,:), means(:,7), '-r')  % Plot Channel 7
plot(combi_intensities(1,:), means(:,8), '-g')  % Plot Channel 8
plot(combi_intensities(1,:), means(:,9), '-m')  % Plot Channel 9
plot(combi_intensities(1,:), means(:,10), '-y')  % Plot Channel 10

% Add the axis labels legend to the plot
legend('Channel1', 'Channel2', 'Channel3', 'Channel4', 'Channel5',...
      'Channel6','Channel7','Channel8', 'Clear', 'NIR');

xlabel('CombiLED Intensity');
ylabel('Mean Channel Value');
title('Mean Channel Value by Intensity');

% Change background color so channel lines are more visible
ax = gca;
ax.Color = [0.9, 0.9, 0.9];  % Light blue background

hold off;


% Create the line graph of STD by intensity for every channel
figure; 

plot(combi_intensities(1,:), standard_deviations(:,1), '--r') % Plot Channel 1

hold on;
plot(combi_intensities(1,:), standard_deviations(:,2), '--b') % Plot Channel 2
plot(combi_intensities(1,:), standard_deviations(:,3), '--g') % Plot Channel 3
plot(combi_intensities(1,:), standard_deviations(:,4), '--m') % Plot Channel 4
plot(combi_intensities(1,:), standard_deviations(:,5), '--y') % Plot Channel 5
plot(combi_intensities(1,:), standard_deviations(:,6), '--k') % Plot Channel 6
plot(combi_intensities(1,:), standard_deviations(:,7), '-r')  % Plot Channel 7
plot(combi_intensities(1,:), standard_deviations(:,8), '-g')  % Plot Channel 8
plot(combi_intensities(1,:), standard_deviations(:,9), '-m')  % Plot Channel 9
plot(combi_intensities(1,:), standard_deviations(:,10), '-y')  % Plot Channel 10

legend('Channel1', 'Channel2', 'Channel3', 'Channel4', 'Channel5',...
      'Channel6','Channel7','Channel8', 'Clear', 'NIR');

xlabel('CombiLED Intensity');
ylabel('STD of Channel Value');
title('STD of Channel Value by Intensity');

% Get current axes handle
ax = gca;

% Change the background color of the axes
ax.Color = [0.9, 0.9, 0.9];  % Light blue background

hold off;


% Close the serial ports with the devices
CL.serialClose();
MS.serialClose_minispect()

clear CL; 
clear MS; 