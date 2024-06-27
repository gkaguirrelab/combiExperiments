% Set simulation mode
simulateSource = false;
simulateDetector = false;

try

% Which Cal file to use (currently hard-coded)
calDir = fullfile(tbLocateProjectSilent('combiExperiments'),'cal');
calFileName = 'CombiLED_shortLLG_testSphere_ND0x2.mat';

% Load the cal file
load(fullfile(calDir,calFileName),'cals');
cal = cals{end};


% If we are not simulating, initialize the detector
if ~simulateDetector
    % Initialize minispect object
    MS = mini_spect_control();

    % Initialize the chip we want and the mode for it to be in
    chip = MS.chip_name_map("AMS7341");
    chip_functions = MS.chip_functions_map(chip);
    mode = chip_functions('Channels');
end

% If we are not simulating, initialize the light source
if ~simulateSource
    % Initialize combiLED object
    CL = CombiLEDcontrol();
    
    % Update the gamma table
    CL.setGamma(cal.processedData.gammaTable);
end

% Parameters 

% If not simulating, dynamically get channels, otherwise set constant 
if ~simulateDetector
    nChannels = MS.nChannels;
else 
    nChannels = 10;
end 

nPrimarySteps = 10;
nSamplesPerStep = 1;
NDF = "0x2";

% Extract some information regarding the light source that is being used to
% calibrate the minispect
sourceS = cal.rawData.S;
sourceP_abs = cal.processedData.P_device;
nSourcePrimaries = cal.describe.displayPrimariesNum;

% Load the minispect SPDs
miniSpectSPDPath = fullfile(tbLocateProjectSilent('combiExperiments'),'data','AMS7341_spectralSensitivity.mat');
load(miniSpectSPDPath,'T');
minispectS = WlsToS(T.wl);
minispectP_rel = T{:,2:end};
%minispectP_rel = minispectP_rel ./ max(minispectP_rel);

% Reformat that minispect SPDs to be in the space of the sourceSPDs
for ii = 1:size(minispectP_rel,2)
    detectorP_rel(:,ii) = interp1(SToWls(minispectS),minispectP_rel(:,ii),SToWls(sourceS));
end


% Arrays to hold outputs over time series
combi_settings =  nan(nPrimarySteps,nSourcePrimaries);
means = nan(nPrimarySteps,nChannels);
standard_deviations = nan(nPrimarySteps,nChannels);
sphereSPDs = nan(nPrimarySteps,sourceS(3));
predictedCounts = nan(nPrimarySteps,nChannels);


% Make this random by doing 
% myRandom = [2,3,4,5,7,8,0]
% for ii = myRandom
% random range 0.05 0.95
%setting_values = nan(nPrimarySteps,1);
for ii = 1:nPrimarySteps
    % The intensity of every channel of the CL at this timestep
    %primary_setting = 0.05+((ii-1)/(nPrimarySteps-1))*0.9;

    fprintf("Primary Step: %d / %d\n", ii, nPrimarySteps);

    primary_setting = 0.95;

    %setting_values(ii,1) = primary_setting;

    % Set the CombiLED settings
    CL_settings = primary_setting * ones(1,8);

    % Store the settings used
    combi_settings(ii,:) = CL_settings;

    % Derive the sphereSPD for this step in units of W/m2/sr/nm. We divide
    % by the nanometer sampling given in S to cast the units as nm, as
    % opposed to (e.g.) per 2 nm.
    sphereSPDs(ii,:) = (sourceP_abs*CL_settings')/sourceS(2);

    % Derive the prediction of the relative counts based upon the sphereSPD
    % and the minispectP_rel.
    predictedCounts(ii,:) = sphereSPDs(ii,:)*detectorP_rel;

    %disp(predictedCounts)

    % Initialize matrix where Row_i = sample_i, col_i = channel_i
    channel_readings_matrix = nan(nSamplesPerStep,nChannels);

    % Set primaries if we are not simulating
    if ~simulateSource
        CL.setPrimaries(CL_settings);
    end

    % Record N samples from the minispect and get the mean and std of 
    % each col (channel) over this matrix at this Primary step. 
    if ~simulateDetector
        for jj = 1:nSamplesPerStep
            channel_values = MS.read_minispect(chip,mode);


            channel_readings_matrix(jj,:) = channel_values;

        end

        %disp(channel_readings_matrix)
        if(any(isnan(channel_readings_matrix)))
            error('NaNs present in channel readings');
        end 

        % Calculate and save the means/STD of each channel
        means(ii,:) = mean(channel_readings_matrix);
        standard_deviations(ii,:) = std(channel_readings_matrix);
    end

end

if(any(isnan(means)))
    error('NaNs present in mean readings');
end 

% Create a histogram of the counts of thre first channel
figure 

plot(means)

hold on ;

xlabel('Time');
ylabel('Count Value');
title('Count Values Over Time for Channel 1');

% Change background color so channel lines are more visible
ax = gca;
ax.Color = [0.9, 0.9, 0.9];  % Light blue background

hold off;

% Save the figure
saveas(gcf,'/Users/zacharykelly/Aguirre-Brainard Lab Dropbox/Zachary Kelly/FLIC_admin/Equipment/MiniSpect/calibration/channel_1_100measures' + NDF + '.jpg');

% Create the line graph of mean by intensity for every channel
figure;

plot(combi_settings(:,1), means(:,1), '--r') % Plot Channel 1

hold on;
plot(combi_settings(:,1), means(:,2), '--b') % Plot Channel 2
plot(combi_settings(:,1), means(:,3), '--g') % Plot Channel 3
plot(combi_settings(:,1), means(:,4), '--m') % Plot Channel 4
plot(combi_settings(:,1), means(:,5), '--y') % Plot Channel 5
plot(combi_settings(:,1), means(:,6), '--k') % Plot Channel 6
plot(combi_settings(:,1), means(:,7), '-r')  % Plot Channel 7
plot(combi_settings(:,1), means(:,8), '-g')  % Plot Channel 8
plot(combi_settings(:,1), means(:,9), '-m')  % Plot Channel 9
plot(combi_settings(:,1), means(:,10), '-y')  % Plot Channel 10

% Add the axis labels legend to the plot
legend('Channel1', 'Channel2', 'Channel3', 'Channel4', 'Channel5',...
    'Channel6','Channel7','Channel8', 'Clear', 'NIR');

xlabel('CombiLED Setting');
ylabel('Channel Value');
title('Channel Value by Setting');

% Change background color so channel lines are more visible
ax = gca;
ax.Color = [0.9, 0.9, 0.9];  % Light blue background


hold off;

% Save the figure
saveas(gcf,'/Users/zacharykelly/Aguirre-Brainard Lab Dropbox/Zachary Kelly/FLIC_admin/Equipment/MiniSpect/calibration/channel_means_by_setting' + NDF + '.jpg');


% Create the line graph of STD by intensity for every channel
figure;

plot(combi_settings(:,1), standard_deviations(:,1), '--r') % Plot Channel 1

hold on;
plot(combi_settings(:,1), standard_deviations(:,2), '--b') % Plot Channel 2
plot(combi_settings(:,1), standard_deviations(:,3), '--g') % Plot Channel 3
plot(combi_settings(:,1), standard_deviations(:,4), '--m') % Plot Channel 4
plot(combi_settings(:,1), standard_deviations(:,5), '--y') % Plot Channel 5
plot(combi_settings(:,1), standard_deviations(:,6), '--k') % Plot Channel 6
plot(combi_settings(:,1), standard_deviations(:,7), '-r')  % Plot Channel 7
plot(combi_settings(:,1), standard_deviations(:,8), '-g')  % Plot Channel 8
plot(combi_settings(:,1), standard_deviations(:,9), '-m')  % Plot Channel 9
plot(combi_settings(:,1), standard_deviations(:,10), '-y')  % Plot Channel 10

legend('Channel1', 'Channel2', 'Channel3', 'Channel4', 'Channel5',...
    'Channel6','Channel7','Channel8', 'Clear', 'NIR');

xlabel('CombiLED Setting');
ylabel('STD of Channel Value');
title('STD of Channel Value by Setting');

% Get current axes handle
ax = gca;

% Change the background color of the axes
ax.Color = [0.9, 0.9, 0.9];  % Light blue background

% Save the figure
saveas(gcf,'/Users/zacharykelly/Aguirre-Brainard Lab Dropbox/Zachary Kelly/FLIC_admin/Equipment/MiniSpect/calibration/channel_std_by_setting' + NDF + '.jpg');

hold off;

% Save the values themselves
save('/Users/zacharykelly/Aguirre-Brainard Lab Dropbox/Zachary Kelly/FLIC_admin/Equipment/MiniSpect/calibration/channel_means' + NDF + '.mat','means');
save('/Users/zacharykelly/Aguirre-Brainard Lab Dropbox/Zachary Kelly/FLIC_admin/Equipment/MiniSpect/calibration/channel_std' + NDF + '.mat','standard_deviations');
save('/Users/zacharykelly/Aguirre-Brainard Lab Dropbox/Zachary Kelly/FLIC_admin/Equipment/MiniSpect/calibration/relative_counts_predictions' + NDF + '.mat','predictedCounts');

% Close the serial ports with the devices if we did not simulate them
if ~simulateSource
    CL.serialClose();
    clear CL;
end

if ~simulateDetector
    MS.serialClose_minispect();
    clear MS;
end

catch e
    disp('Catching Error and closing ports')
    
    disp(e)
    
    CL.serialClose();
    clear CL;
    MS.serialClose_minispect();
    clear MS;
end