function serialClose(obj)

% Close the serial port
clear obj.serialObj
obj.serialObj = [];

if obj.verbose
    fprintf('Serial port closed\n');
end

% Enter simulation mode since we have closed the 
% real device
obj.simulate = true; 

end