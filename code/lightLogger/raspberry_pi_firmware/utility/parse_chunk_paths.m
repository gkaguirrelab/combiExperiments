function sorted_chunks = parse_chunk_paths(path_to_experiment)
% Parses a chunk recording from the RPI into a cell of cells 
% containing the paths to the sensors' info from each chunk (sorted)
%
% Syntax:
%   sorted_chunks = parse_chunk_paths(path_to_experiment)
%
% Description:
%   Parse a recording file for recordings made in chunk format 
%   on the RPI into a sorted cell of cell where the second 
%   dimension is a cell of paths in sorted (ASCII) order 
%   to the sensors' info for this chunk.
%
%
% Inputs:
%   path_to_experiment    - String. The path to the suprafile 
%                           containing all of the chunks.
%
% Outputs:
%
%   sorted_chunks         - 2D Cell. A cell containing cells
%                           of each of the paths to 
%                           sensors' information for each chunk 
%                           sorted by chunk number. 
%
% Examples:
%{
    path_to_experiment = '/Volumes/EXTERNAL1/hourOfChunks_5hz_0NDF';
    sorted_chunks = parse_chunk_paths(path_to_experiment);
%}

    % Parse and validate the input arguments
    arguments 
        path_to_experiment {mustBeText}; % The path to the suprafolder for this experiment

    end

    % First, we must find the path to the current file, so 
    % we can import the Python utility library
    current_filedir = fileparts(mfilename('fullpath'));

    % Then, we must save our current directory before we go 
    % cd to this file 
    cwd = pwd(); 

    % Then, we will cd into the directory where this file is 
    cd(current_filedir);

    % Import the Python utility function 
    Pi_util = py.importlib.import_module('Pi_util');

    % Cd back to the original directory 
    cd(cwd);

    % Next, call the Python utility function to parse 
    % the experiment folder and return each chunks 
    % information path sorted by chunk number
    sorted_chunks = cell(Pi_util.parse_chunk_paths(path_to_experiment))';

    % Now, convert every dict to a struct
    sorted_chunks = cellfun(@(x) struct(x), sorted_chunks, 'UniformOutput', false);

    % Finally, go across all of the dicts and convert all of their py.lists of 
    % strings to MATLAB string array
    for cc = 1:size(sorted_chunks, 1)
        % Retrieve the chunk struct
        chunk_struct = sorted_chunks{cc};
        
        % Now, iterate over the fields
        fieldNames = fieldnames(chunk_struct);

        for ff = 1:numel(fieldNames)
            % Retrieve the name of the field 
            fieldName = fieldNames{ff};
            
            % Convert the list of strings to a string 
            % array
            chunk_struct.(fieldName) = string(chunk_struct.(fieldName));

        end 

        % Resave this chunk 
        sorted_chunks{cc} = chunk_struct;

    end



    return ; 


end