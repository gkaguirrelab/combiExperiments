function channel_values = parse_channel_reading(obj, reading)
% Parses the lines read from the minispect in the channels mode to return only numeric values 
%
% Syntax:
%   channel_values = MS.parse_channel_reading(reading)
%
% Description:
%   Parses the lines read from the minispect in the channels mode to return only numeric values 
%
% Inputs:
%   reading                - Array. Represents the lines read from the minispect
%                           to parse.               
% Outputs:
%   channel_values         - Array. Represents the numeric channel values in order
%
% Examples:
%{
    MS = mini_spect_control();
    reading = ['Channel1 : 54','Channel2 : 26'];
    channel_values = MS.parse_channel_reading(reading);
%}
    
    channel_values = nan(1,10);

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