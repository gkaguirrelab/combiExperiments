function result = write_minispect(obj, chip, mode, write_val)
% Writes information to a specific chip and its specific mode on the minispect
%
% Syntax:
%   result = MS.write_minispect(chip,mode,write_val);
%
% Description:
%   Writes write_val to the specific chip and mode on the minispect. 
%
% Inputs:
%   chip                   - Char. Represents the first letter of the chip to 
%                          read from. 
%   mode                   - Char. Represents the first letter of the mode to 
%                           use for reading.     
%  write_val              - String. Represents the value to write to the minispect.    
%          
% Outputs:
%   result                 - Array. Represents the lines read from the minispect,
%                           parsed accordingly. 
%
% Examples:
%{
    MS = mini_spect_control();
    chip = MS.chip_name_map("ASM7341");
    chip_functions = MS.chip_functions_map(chip);
    mode = chip_functions('Gain');
    write_val = 5;
    reading = MS.write_minispect(chip,mode,write_val); 
%}
    
    
    
    % Ensure we have a real device connected
    if(obj.simulate) 
        error('Cannot write. Device in simulation mode.');
    end
    
    % Initialize empty result for the lines read
    result = {};

    % Send the message to write a specific piece of data 
    % to the minispect's specific chip 
    writeline(obj.serialObj,['W', chip, mode, num2str(write_val)]);     

    % Read lines while we receive them 
    i = 1 ;
    while true
        line = readline(obj.serialObj);
        has_terminator = contains(line, obj.END_MARKER);

        % Break if we hit the end of message terminator
        if has_terminator
            break; 
        end 
        
        % Clean them up by removing white space, 
        % and store them in result. 
        result{i} = strtrim(line);

        i = i + 1;
        
    end 
    
    % Throw an error if the minispect reported an error
    if strcmp(result{end}, "-1")
        error('minispect write failed.');
    end 
    

    