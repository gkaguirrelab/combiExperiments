% Initialize the minispect_controller
MS = mini_spect_control(verbose=true);

% Attempt to get a reading from the minispect
try
    chip = MS.chip_name_map("ASM7341");

    chip_functions = MS.chip_functions_map(chip);
    mode = chip_functions('Gain');
    
    reading = MS.read_minispect(chip,mode);



% Display an error (if occured) and close the serial port connection 
catch e
    disp("ERROR OCCURED");
    disp(e.identifier);
    disp(e.message);
    MS.serialClose_minispect();
    clear MS
    return 
end 

% Close the serial port connection
MS.serialClose_minispect();
clear MS