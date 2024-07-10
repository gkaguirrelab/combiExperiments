function test_integration_stability(obj,NDF,cal_path,chip)
    % Ensure we have a real device connected
    if(obj.simulate)
        error('Cannot calibrate. Device in simulation mode.')
    end