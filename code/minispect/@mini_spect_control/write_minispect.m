function result = write_minispect(obj, chip, mode, write_val)
    % Ensure we have a real device connected
    if(obj.simulate) 
        error('Cannot write. Device in simulation mode.');
    end
    
    % Initialize empty result for the lines read
    result = {};

    % Send the message to write a specific piece of data 
    % to the minispect's specific chip 
    writeline(obj.serialObj,['W', chip, mode, char(write_val)]);     

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
        result{i} = strtrim(line);
         
        i = i + 1;
         
     end 

    
    % Throw an error if the minispect reported an error
    if strcmp(result{1}, "-1")
        error('minispect write failed.');
    end 

    disp(results)
    

    