% This script serves as an informal introduction to the LIS2DUXS12 
% Accelerometer in the MiniSpect

% Step 1: Connect the MiniSpect 
MS = mini_spect_control(); 

% Step 2: Denote the chip and mode we want to read
chip = MS.chip_name_map('LIS2DUXS12');
chip_functions = MS.chip_functions_map(chip);
mode = chip_functions('Accel');

time_per_measure = 0;
nMeasures = 10000; 

% Step 3: Face the minispect-equipped spectacles
%         towards the screen and observe how its 
%         values change
tic ; 
for ii = 1:nMeasures
    accel_values = MS.read_minispect(chip,mode);
    
    fprintf('Measurement %d / %d\n', ii, nMeasures);

    fprintf('X: %d | Y: %d | Z: %d\n', accel_values(1),accel_values(2),accel_values(3));   
end

% Step 4: Close the serial connection to the MS
MS.serialClose_minispect(); 
clear MS; 

% Step 5: Find the speed at which the sensor is able to get readings
elapsed_seconds = toc ; 
time_per_measure = elapsed_seconds / nMeasures;

fprintf('Time per measure: %f seconds\n', time_per_measure);

% Thus, in its configuration on the spectacles, we find that 
% +-X denotes forward and backward movement, +-Y denotes right 
% and left movement, and +-Z denotes upward, and downward 
% movement respectively. We also find that it's measurement time 
% is 0.007916 seconds.