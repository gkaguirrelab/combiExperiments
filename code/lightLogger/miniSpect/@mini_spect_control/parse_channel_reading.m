function channel_values = parse_channel_reading(obj, reading, chip)
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
    % Initialize container to store nChannels' readings 
    % based on the nChannels of the chip that was read from 
    channel_values = nan(1,obj.chip_nChannels_map(chip));

    % Add debugging offset because the arduino will
    % currently print some text like 'Reading TS'
    % that are not values we want to read
    debugging_output_offset = 0; 

    % Iterate over the reading as lines of strings
    for i = 1:size(reading,2)
        % Find where the ':' is in the string that 
        % seperates a channel name to it's reading 
        % (ie. Channel 0 : 24)
        text_val_separators = strfind(reading(1,i), ':');
        
        % If we didn't find a separator, it's a debugging output
        % so increase the offset and go to the next line
        if(isempty(text_val_separators))
            debugging_output_offset = debugging_output_offset + 1; 
            continue
        end
    
        % Find the index of the seperator 
        text_val_seperator_indx = text_val_separators(1);

        % Convert string line into character vector
        reading_as_charvec = char(reading(i));

        % Splice only thr numeric part of the string, trim whitespace, and convert it to numeric 
        channel_val = str2num( strtrim( reading_as_charvec(text_val_seperator_indx+1:end) ) );

        % Save the channel value to its appropriate position
        channel_values(i-debugging_output_offset) = channel_val;
    end

end