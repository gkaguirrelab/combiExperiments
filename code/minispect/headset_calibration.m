function headset_calibration() 
% An outline of how to fully calibrate the head-mounted device
%
% Syntax:
%   headset_calibration()
%
% Description:
%   Calibrate all of the components of the head-mounted device
%
% Inputs:
%
%
% Outputs:
%
%
% Examples:
%{
  headset_calibration()
%}

    % {SETUP: Define global variables}
    source_cal_path = 'test';

    % {PART 1: Calibrate the MiniSpect}
    
    % Step 1.1: Open a connection to the MiniSpect
    MS = mini_spect_control(); 
    chip = MS.chip_name_map('SEEED');
    chip_functions = MS.chip_functions_map(chip);
    mode = chip_functions('SerialNumber');
    device_serial_number = MS.read_minispect(chip, mode);

    % Step 1.2: Use its calibration function to generate cal_files
    %MS.calibrate_minispect(2,'./calfile',10,[0.05,0.95],10,3,1,'./calibration') 
    NDF = 2; 
    nPrimarySteps = 10; 
    settingsScalarRange = [0.05, 0.95];
    nSamplesPerStep = 10; 
    nReps = 3;
    randomizeOrder = 1; 
    save_path = [getpref('combiExperiments','dropboxBaseDir'), '/FLIC_admin/Equipment/MiniSpect/calibration/'];
    MS.calibrate_minispect(NDF, source_cal_path, nPrimarySteps, settingsScalarRange, nSamplesPerStep, nReps, randomizeOrder, save_path)

    % Step 1.3 Fit the MS calibration 
    calDir = fullfile(save_path, device_serial_number);
    d = dir(fullfile(calDir,'*mat'));
    MSCalDataFiles = cellfun(@(x) fullfile(calDir, x), {d.name}, 'UniformOutput', false);
    fit_calibration(MSCalDataFiles);

    % {PART 2: Analyze MS Temporal Sensitivity}
    
    % Step 2.1 Run the associated script to 
    % analyze temporal sensitivity
    light_sensing_chips = MS.light_sensing_chips;
    for cc = 1:numel(light_sensing_chips)
        chip = light_sensing_chips(cc);
        analyze_ms_temporal_sensitivty(source_cal_path, chip); 
    end

    % {PART 3: Analyze Camera Temporal Sensitivity}

    % Step 3.1 Run the associated script to analyize 
    % temporal sensitivity  
    output_filename = 'test';
    analyze_camera_temporal_sensitivity(source_cal_path, output_filename)



end