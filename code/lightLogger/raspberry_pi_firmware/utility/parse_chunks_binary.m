function [chunks, performance_struct] = parse_chunks_binary(path_to_experiment, use_mean_frame)
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
%   sorted_chunks         - Cell. A cell containing structs with 
%                           paths to each of the sensors' info 
%                           for that chunk.
%
% Examples:
%{
    path_to_experiment = '/Volumes/EXTERNAL1/newJson';
    [chunks, performance_struct] = parse_chunks_binary(path_to_experiment);
%}


    % Parse and validate the input arguments
    arguments 
        path_to_experiment {mustBeText}; % The path to the suprafolder for this experiment
        use_mean_frame {mustBeNumericOrLogical} = false; % Bool (true/false) for whether to return the full frames or mean of each frame
    end


    % Next, we will import the utility module with this functionality written in Python 

    % First we must save the directory we are currently in so we can return to it after importing
    cwd = pwd();

    % Next we will construt the path to the Python pi_util module
    Pi_util_dir = fileparts(mfilename('fullpath')); 

    % Now, we will cd into the Pi util dir and import the module 
    cd(Pi_util_dir);
    Pi_util = py.importlib.import_module('Pi_util');

    % Return to the original working directory 
    cd(cwd);

    % Now, we will read in the files by calling the appropriate Python function 
    chunks_as_py = struct(Pi_util.parse_chunks_binary(path_to_experiment, true));  

    % Now, we will finish converting this object into all native MATLAB types
    
    % First, convert the performance data to MATLAB type 
    chunks_as_py.performance_dict = struct(chunks_as_py.performance_dict); 
    field_names = fieldnames(chunks_as_py.performance_dict);

    for cc = 1:numel(field_names) 
        % We will handle several fields in unique ways due to how the data is structued 
        if(field_names{cc} == "controller_names")
            % Array of chars, so simply convert with string 
            chunks_as_py.performance_dict.(field_names{cc}) = string(chunks_as_py.performance_dict.(field_names{cc}));
            
            continue ; 
        end 

        if(field_names{cc} == "controllers_used")
            % Boolean array, so simply convert with logical 
            chunks_as_py.performance_dict.(field_names{cc}) = logical(chunks_as_py.performance_dict.(field_names{cc}));
            
            continue ; 
        end

        if(field_names{cc} == "sensor_FPS_settings")
            % py.list with ints in it, so first convert to cell
            chunks_as_py.performance_dict.(field_names{cc}) = cell(chunks_as_py.performance_dict.(field_names{cc}));

            % Then convert everything to double
            chunks_as_py.performance_dict.(field_names{cc}) = cellfun(@double, chunks_as_py.performance_dict.(field_names{cc}));
            
            continue ; 
        end

        if(field_names{cc} == "sensor_size_settings")
            % Py.list wherein each element is a list with 2 elements, so first convert to cell 
            chunks_as_py.performance_dict.(field_names{cc}) = cell(chunks_as_py.performance_dict.(field_names{cc}));

            % Then convert inner lists to double arrays, then outer cell to mat array
            chunks_as_py.performance_dict.(field_names{cc}) = cell2mat(cellfun(@double, chunks_as_py.performance_dict.(field_names{cc}), 'UniformOutput', false));
            
            continue ; 
        end 

        % Default behavior is simply just convert with double
        chunks_as_py.performance_dict.(field_names{cc}) = double(chunks_as_py.performance_dict.(field_names{cc}));
          
    end
    
    % % Convert the outer list of chunks to MATLAB type 
    chunks_as_py.chunks = cell(chunks_as_py.chunks); 

    % Now, we will iterate over the chunks and convert them to MATLAB type 
    for cc = 1:numel(chunks_as_py.chunks) 
        % Retrieve the dictionary chunk for chunk cc and convert to struct first 
        chunk_dict = struct(chunks_as_py.chunks{cc}); 
        
        % First, let's convert the MS, as this data structure is unique. 
        % The MiniSpect data is in a tuple of pd.dataframes
        chunk_dict.M = cell(chunk_dict.M); % First, we convert the tuple to a cell
        
        for df = 1:numel(chunk_dict.M)  % Then we will convert all the dfs to tables 
            chunk_dict.M{df} = table(chunk_dict.M{df});
        end 

        % Then, the other data is all in similar structure. That is, np.ndarray format. Thus we can use a loop
        field_names = fieldnames(chunk_dict); % First retrieve the field names so we can iterate over them 

        for ff = 2:numel(field_names) % Skip the MS (first field) since we've already converted it
            % Convert the numpy arrays to MATLAB type
            chunk_dict.(field_names{ff}) = double(chunk_dict.(field_names{ff}));
        end

        % Reassign this chunk back into the array 
        chunks_as_py.chunks{cc} = chunk_dict;

    end

    % Return the final converted values
    performance_struct = chunks_as_py.performance_dict;
    chunks = chunks_as_py.chunks; 