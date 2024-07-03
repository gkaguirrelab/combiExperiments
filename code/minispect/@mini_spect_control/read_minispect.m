function result = read_minispect(obj, chip, mode)
% Reads information from a specific chip and its specific mode from the minispect
%
% Syntax:
%   result = MS.read_minispect(chip,mode);
%
% Description:
%  Reads information from the minispect's given chip and mode. Cleans output
%  and further parses when needed for specific modes (i.e, channel readings).
%
% Inputs:
%   chip                   - Char. Represents the first letter of the chip to 
%                          read from. 
%   mode                   - Char. Represents the first letter of the mode to 
%                           use for reading.                  
% Outputs:
%   result                 - Array. Represents the lines read from the minispect,
%                           parsed accordingly. 
%
% Examples:
%{
    MS = mini_spect_control();
    chip = MS.chip_name_map("SEEED");

    chip_functions = MS.chip_functions_map(chip);
    mode = chip_functions('SerialNumber');
    reading = MS.read_minispect(chip,mode);
%}

    % Ensure we have a real device connected
    if(obj.simulate)
        error('Cannot read. Device in simulation mode.');
    end

    % Initialize empty result for the lines read
    result = []; 

    % Send the message to read a specific piece of data 
    % from the minispect's specific chip 
    writeline(obj.serialObj,['R', chip, mode]);     

    % Read lines while we receive them 
    i = 1 ;
    while true
        line = readline(obj.serialObj);
        has_terminator = contains(line, obj.END_MARKER);

        % Break if we hit the end of message terminator
        if has_terminator
            break; 
        end 

        % Clean them up by removing white space and terminator, 
        % and store them in result. 
        result = [result, strtrim(line)];
        
        i = i + 1;  
        
    end 
    
    % Throw an error if the minispect reported an error
    if strcmp(result(1), "-1")
        error('minispect read failed.');
    end 
    
    if strcmp(mode,'C')
        result = obj.parse_channel_reading(result);
    end 
    
    

    