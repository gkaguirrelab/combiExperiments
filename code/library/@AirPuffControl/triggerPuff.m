function triggerPuff(obj,side)
% Trigger a puff.

% Check that we have an open connection
if isempty(obj.serialObjSolenoid)
    warning('Serial connection not yet established');
end

% Sanity check the side string
assert(contains(side,{'L','R'}));

% Prepare the command
command = sprintf([side 'PULSE']);

% Send the command and read the echo
writeline(obj.serialObjSolenoid,command);
commandEcho = readline(obj.serialObjSolenoid);

% Say
if obj.verbose
fprintf(strcat(commandEcho,"\n"))
end

end