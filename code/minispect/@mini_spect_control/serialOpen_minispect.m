function serialOpen_minispect(obj) 

    % Get the list of available serial connections
    portList = serialportlist("available");

    % Find the port that is the mini_spect 
    if ismac
        % Find indices where available serial ports contain the string
        % "tty..."
        arduinoPortIdx = find((contains(serialportlist("available"),'tty.usbmodem')));
        
        arduinoPort = portList(arduinoPortIdx);
    end

    % We can't find a port
    if isempty(arduinoPort)
        error('Unable to find a connected and available arduino board');
    end

    % Open the serial port
    obj.serialObj = serialport(arduinoPort,obj.baudrate);

    % Use CR and LF as a terminator
    configureTerminator(obj.serialObj,"CR/LF");

    % Announce it
    if obj.verbose
        fprintf('Serial port open\n');
    end

    % End simulation mode since we connected to a real device
    obj.simulate = false; 

end 