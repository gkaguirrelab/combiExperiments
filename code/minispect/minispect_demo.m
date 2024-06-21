% Initialize the minispect_controller
MS = mini_spect_control(verbose=true);

% Attempt to get a reading from the minispect
try
    reading = MS.read_minispect('A','G');

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