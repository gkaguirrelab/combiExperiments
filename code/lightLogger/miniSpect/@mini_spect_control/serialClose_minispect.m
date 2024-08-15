function serialClose_minispect(obj)
% Closes the serial port connection with the minispect.  
%
% Syntax:
%   MS.serialClose_minispect();
%
% Description:
%   Closes the serial port connection with the minispect.  
%
% Inputs:
%   NONE                
%              
% Outputs:
%   NONE       
%
% Examples:
%{
    MS = mini_spect_control();
    MS.serialClose_minispect(); 
%}

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