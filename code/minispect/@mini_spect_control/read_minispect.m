function lines = read_minispect(obj)
    lines = "";
 
    writeline(obj.serialObj,'R');     

    for i = 1:15
      lines = lines + readline(obj.serialObj) + newline;
      
    end 
    
    disp(lines);
    

    