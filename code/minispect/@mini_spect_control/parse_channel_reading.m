function channel_values = parse_channel_reading(obj, reading)
    channel_values = zeros(1,10);

    debugging_output_offset = 0; 
    for i = 1:size(reading,2)
        text_val_separators = strfind(reading(1,i), ':');
        if(isempty(text_val_separators))
            debugging_output_offset = debugging_output_offset + 1; 
            continue
        end
        
        text_val_seperator_indx = text_val_separators(1);

        reading_as_charvec = char(reading(i));

        channel_val = str2num( strtrim( reading_as_charvec(text_val_seperator_indx+1:end) ) );

        channel_values(i-debugging_output_offset) = channel_val;
    end

end