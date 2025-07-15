function serialOpen(obj)

% Get the list of available serial connections
portList = serialportlist("available");

% Error if we are not on a mac
if ~ismac
    error('Need to set this up for a non-Mac environment');
end

%% Open connection to the EPC
portIdxEPC = find(and(contains(portList,obj.portcodeEPC),contains(portList,'tty')));
portEPC = portList(portIdxEPC);

% We can't find a port
if isempty(portEPC)
    error('Unable to find a connected and available Alicat EPC board');
end

% Open the serial port
obj.serialObjEPC = serialport(portEPC,obj.baudrateEPC);

% Use CR as a terminator
configureTerminator(obj.serialObjEPC,obj.linebreakEPC);

% Announce it
if obj.verbose
    fprintf('EPC serial port open\n');
end


%% Open connection to the solenoids (which are controlled by an arduino)
portIdxSolenoid = find(and(contains(portList,obj.portcodeSolenoid),contains(portList,'tty')));
portSolenoid = portList(portIdxSolenoid);

% We can't find a port
if isempty(portSolenoid)
    error('Unable to find a connected and available arduino board controlling the solenoids');
end

% Open the serial port
obj.serialObjSolenoid = serialport(portSolenoid,obj.baudrateSolenoid);

% Use CR and LF as a terminator
configureTerminator(obj.serialObjSolenoid,obj.linebreakSolenoid);

% Announce it
if obj.verbose
    fprintf('Solenoid serial port open\n');
end



end