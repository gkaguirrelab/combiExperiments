function setPressure(obj,side,stimPressurePSI)
% Send a pressure level to one "side" (left or right) of the Alicat
% Electronic Pressure Controller (EPC)

% Check that we have an open connection
if isempty(obj.serialObjEPC)
    warning('Serial connection not yet established');
end

% Sanity check the side string
assert(contains(side,{'L','R'}));

% Sanity check the value, cannot be greater than 20.
assert(stimPressurePSI<=20);

% Prepare the command
command = sprintf([side 's%2.2f'],stimPressurePSI);

% Send the command and read the echo
writeline(obj.serialObjEPC,command);
commandEcho = readline(obj.serialObjEPC);

% Say
if obj.verbose
    fprintf(strcat(commandEcho,"\n"));
end

end