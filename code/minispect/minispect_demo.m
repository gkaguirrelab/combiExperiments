% Initialize the minispect_controller
MS = mini_spect_control(verbose=true);

% Attempt to get a reading from the minispect
try
    chip = MS.chip_name_map("SEEED");

    chip_functions = MS.chip_functions_map(chip);
    mode = chip_functions('SerialNumber');
    reading = MS.read_minispect(chip,mode);

    disp(reading)

    % Read the gain
    %mode = chip_functions('Gain');
    %reading = MS.read_minispect(chip,mode);
    
    % Read the integration information
   % mode = chip_functions('Integration');
    %reading = MS.read_minispect(chip,mode);
    
    % Read the channels
    %mode = chip_functions('Channels');
    %values = MS.read_minispect(chip,mode);
    
    %disp(values)

    % Write a new gain value 
    %mode = chip_functions('Gain');
    %write_val = 5;
    %reading = MS.write_minispect(chip,mode,write_val); 

    % See if it updated 
    %mode = chip_functions('Gain');
    %reading = MS.read_minispect(chip,mode);



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