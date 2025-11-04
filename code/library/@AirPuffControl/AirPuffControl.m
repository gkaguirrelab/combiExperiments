% Object to support controlling the AirPuff device created by Vincent Lau.
% This device has multiple components, including IR cameras connected to an
% RPI, a dual channel pressure regulator system, and solenoids under the
% control of an Arduino Seeed Studio Xiao for delivering puffs.

classdef AirPuffControl < handle

    properties (Constant)

        baudrateEPC = 19200;
        linebreakEPC = "CR";
        portcodeEPC = ["B400I036","tty"];

        baudrateSolenoid = 115200;
        linebreakSolenoid = "CR/LF";
        portcodeSolenoid = ["usbmodem","01","tty"];

    end

    % Private properties
    properties (GetAccess=private)

    end

    % Calling function can see, but not modify
    properties (SetAccess=private)

        serialObjEPC
        serialObjSolenoid
        deviceState

    end

    % These may be modified after object creation
    properties (SetAccess=public)

        % Verbosity
        verbose = false;

    end

    methods

        % Constructor
        function obj = AirPuffControl(varargin)

            % input parser
            p = inputParser; p.KeepUnmatched = false;
            p.addParameter('verbose',true,@islogical);
            p.parse(varargin{:})

            % Store the verbosity
            obj.verbose = p.Results.verbose;

            % Open the serial port
            obj.serialOpen;

        end

        % Required methds
        serialOpen(obj)
        serialClose(obj)
        sendPressure(obj,side,stimPressurePSI)
        setDuration(obj,side,stimDurMsec)
        triggerPuff(obj,side)

    end
end