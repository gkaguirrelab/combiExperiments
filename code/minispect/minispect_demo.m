MS = mini_spect_control(verbose=true);
   
try
    reading = MS.read_minispect();

catch e
    disp("ERROR OCCURED");
    disp(e.identifier);
    disp(e.message);
    MS.serialClose_minispect();
    clear MS
    return 
end 

MS.serialClose_minispect();
clear MS