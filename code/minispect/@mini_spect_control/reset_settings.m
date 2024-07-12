function reset_settings(obj)
% Resets MS chips settings to those chosen by us
    
    % Ensure we have a real device connected
    if(obj.simulate)
        error('Cannot reset settings. Device in simulation mode.');
    end

    % Fields and settings for AS chip
    as_fields = {'Gain','ATIME','ASTEP'};
    as_settings = [5, 249, 259];

    % Fields and settings for the TS chip
    ts_fields = {'Gain','ATIME'};
    ts_settings = [32,4];

    % Reset AS chip settings
    chip = obj.chip_name_map('AMS7341');
    chip_functions = obj.chip_functions_map(chip);
    for ff = 1:size(as_fields,2)
        % Get the mode/field to write to 
        % and the val to write
        mode = chip_functions(as_fields{ff});
        write_val = as_settings(ff);

        % Write the value
        obj.write_minispect(chip,mode,write_val);

        % Ensure it was set properly
        ret = obj.read_minispect(chip,mode);
        assert(str2num(ret) == write_val);
    end


    % Reset TS chip settings
    chip = obj.chip_name_map('TSL2591');
    chip_functions = obj.chip_functions_map(chip);
    for ff = 1:size(ts_fields,2)
        % Get the mode/field to write to 
        % and the val to write
        mode = chip_functions(ts_fields{ff});
        write_val = ts_settings(ff);

        % Write the value
        obj.write_minispect(chip,mode,write_val);

        % Ensure it was set properly
        ret = obj.read_minispect(chip,mode);
        assert(str2num(ret) == write_val);
    end

end