function serialClose(obj)

% Place the mini_spect in Run Mode
switch obj.deviceState
    case 'RUN'
    case {'CONFIG','DIRECT'}
        writeline(obj.serialObj,'RM');
        readline(obj.serialObj);
        obj.deviceState = 'RUN';
end

% Close the serial port
clear obj.serialObj
obj.serialObj = [];

if obj.verbose
    fprintf('Serial port closed\n');
end

end