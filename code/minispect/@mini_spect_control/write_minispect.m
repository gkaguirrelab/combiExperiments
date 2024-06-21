function result = write_minispect(obj, chip, mode, write_val)

    % Send the message to write a specific piece of data 
    % to the minispect's specific chip 
    writeline(obj.serialObj,['R', chip, mode, write_val]);     
    

    