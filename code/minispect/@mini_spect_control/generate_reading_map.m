function map = generate_reading_map(obj)
    map = containers.Map('KeyType','char',...
                           'ValueType','uint16');
    
    % TSL HDR Light Sensor Measurements
    % as time series
    %map("IR") = [];
    %map("Full") = [];
    %map("Visible") = [];
    

    % Light Sensor Channel measurements as 
    % time series 
    % map("ADC0/F1") = [0];
    % map("ADC1/F2") = [];
    % map("ADC2/F3") = [];
    % map("ADC3/F4") = [];
    % map("ADC0/F5") = [];
    % map("ADC1/F6") = [];
    % map("ADC2/F7") = [];
    % map("ADC3/F8") = [];
    % map("ADC4/Clear") = [];
    % map("ADC5/NIR") = [];
    
    % Sensor Information as time series
    %map("Gain") = [];
    %map("Integration Time") = [];

