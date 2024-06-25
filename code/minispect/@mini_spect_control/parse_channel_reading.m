function channel_values = parse_channel_reading(obj, reading)
    channel_values = zeros(1,13);

    for i = 1:size(reading,2)
        text_val_separators = strfind(reading{1,i}, ':');
        if(isempty(text_val_separators))
            continue
        end
        
        text_val_seperator_indx = text_val_separators(1);

        reading_as_charvec = char(reading{i});
        channel_val = str2num( strtrim( reading_as_charvec(text_val_seperator_indx+1:end) ) );

        channel_values(i) = channel_val;
    end

end