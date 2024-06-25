addpath('/Users/zacharykelly/Documents/MATLAB/toolboxes/combiLEDToolbox/code');

% Parameters
nPrimarySteps = 10; 
nSamplesPerStep = 10;

% Initialize combiLED object
CL = CombiLEDcontrol();

% Initialize minispect object
MS = mini_spect_control();

% Initialize the chip we want and the mode for it to be in
chip = MS.chip_name_map("ASM7341");
mode = MS.chip_functions_map("Channels");

combi_intensities = {};
means = {};
standard_deviations = {};


for i = 1:nPrimarySteps
    % The intensity of every channel of the CL at this timestep
    channel_intensity = 0.05+((i-1)/(nPrimarySteps-1))*0.9;
    combi_intensities{i} = channel_intensity;

    % Set the CombiLED settings
    CL_settings = channel_intensity * ones(1,8);
    CL.setPrimaries(Cl_settings);
    
    % Initialize matrix where Row_i = sample_i, col_i = channel_i 
    channel_readings_matrix = zeros(nSamplesPerStep,13);
    
    % Record N samples from the minispect
    for j = 1:nSamplesPerStep
        channel_values = MS.read_minispect(chip,mode); 

        channel_readings_matrix(j) = channel_values; 
    end


end