function triggerPuff(obj,side)
% Trigger a puff.

% Check that we have an open connection
if isempty(obj.serialObjSolenoid)
    warning('Serial connection not yet established');
end

% Sanity check the side string
assert(contains(side,{'L','R','LR','RL','B'}));

% Send the command and read the echo
switch side
    case 'L'
        writeline(obj.serialObjSolenoid,'LPULSE');
    case 'R'
        writeline(obj.serialObjSolenoid,'RPULSE');
    case {'RL','LR','B'}
        writeline(obj.serialObjSolenoid,'ALLPULSE');
end

% Say
if obj.verbose
    commandEcho = readline(obj.serialObjSolenoid);
    fprintf(strcat(commandEcho,"\n"))
end

end