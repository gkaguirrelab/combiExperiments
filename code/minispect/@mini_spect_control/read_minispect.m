function result = read_minispect(obj, chip, mode)
    % Initialize empty result
    result = "";

    % Send the message to read a specific piece of data 
    % from the minispect's specific chip 
    writeline(obj.serialObj,['R', chip, mode]);     

    % Read lines while we receive them 
    while true
        if obj.NumBytesAvailable > 0    
            line = readline(obj);

            result = result + line + newline;
        end
        
        % Break if we hit the end of message terminator
        if contains(line, obj.END_MARKER)
            break; 
        end 
    
    end 

    disp(result)
    

    