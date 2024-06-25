% Parameters
nPrimarySteps = 10; 
nSamplesPerStep = 10;

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
combi_intensities = {};
means = {};
standard_deviations = {};


for i = 1:nPrimarySteps
    % The intensity of every channel of the CL at this timestep
    channel_intensity = 0.05+((i-1)/(nPrimarySteps-1))*0.9;
    combi_intensities{i} = channel_intensity;

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


end

% Close the serial ports with the devices
CL.serialClose();
MS.serialClose_minispect()

clear CL; 
clear MS; 