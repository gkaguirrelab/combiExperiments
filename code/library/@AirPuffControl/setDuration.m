function setDuration(obj,side,stimDurMsec)
% In configure mode, pass a set of stimulus puff durations in ms units

% Check that we have an open connection
if isempty(obj.serialObjSolenoid)
    warning('Serial connection not yet established');
end

% Sanity check the side string
assert(contains(side,{'L','R'}));

% Sanity check the duration. No value should be greater than 1000.
assert(stimDurMsec<=1000);

% Prepare the command
command = sprintf([side 'DUR %d'],round(stimDurMsec));

% Send the command and read the echo
writeline(obj.serialObjSolenoid,command);
commandEcho = readline(obj.serialObjSolenoid);

% Say
if obj.verbose
fprintf(strcat(commandEcho,"\n"))
end

end