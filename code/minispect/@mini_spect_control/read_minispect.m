function result = read_minispect(obj, chip, mode)
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
    
    

    