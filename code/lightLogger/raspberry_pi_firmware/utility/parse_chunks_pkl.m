function sorted_chunks_parsed = parse_chunks_pkl(path_to_experiment, use_mean_frame)
% Parse the chunks of a chunked recording by reading in each chunk's pkl file data 
% and converting it all to native MATLAB types. 
%
% Syntax:
%   sorted_chunks_parsed = parse_chunks_pkl(path_to_experiment)
%
% Description:
%   Reads in the chunks from an experiment and all of their
%   associated data when they are stored as .pkl files, 
%   then converts them to MATLAB types
%
%
% Inputs:
%   path_to_experiment    - String. The path to the suprafile 
%                           containing all of the chunks.
%
%   path_to_experiment    - Boolean. Whether to return mean
%                           values for each frame instead of 
%                           the full frame for each 
%                           video sensor. 
%
%
% Outputs:
%
%   sorted_chunks_parsed  - Cell. A cell containing structs 
%                           of all of the sensors' data 
%                           for a given chunk.  
% Examples:
%{
    path_to_readings = './results';
    sorted_chunks_parsed = parse_chunks_pkl(path_to_experiment) 
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
    chunks_as_py = cell(Pi_util.parse_chunks_pkl(path_to_experiment, use_mean_frame));

    % Now let's iterate over the chunks and convert them to MATLAB type 
    for cc = 1:numel(chunks_as_py)
        fprintf('Converting chunk: %d/%d to MATLAB type\n', cc, numel(chunks_as_py));
        
        % First, retrieve the py.dict 
        chunk_dict = chunks_as_py{cc};

        % Then, simply convert to struct
        chunk_struct = struct(chunk_dict);

        % Now we will need to convert individual field dicts to MATLAB types
        field_names = fieldnames(chunk_struct);

        disp(chunk_struct)

        for ff = 1:numel(field_names)
            % Convert this field, which is a py.dict, to MATLAB struct
            field_struct = struct(chunk_struct.(field_names{ff}));

            fprintf('Converting field: %s\n', field_names{ff});
            disp(field_struct)

            % However, this is not all. We now need to iterate over THAT dict
            % and convert numpy arrays to MATLAB double arrays 
            subfields = fieldnames(field_struct);
            for sf = 1: numel(subfields)
                fprintf('Converting subfield: %s\n', subfields{sf});

                % Convert the subfield to MATLAB type, double for 
                % Python numeric types and numpy arrays, table for pd.DataFrames
                % used for the MS
                if(isa(field_struct.(subfields{sf}), 'py.pandas.core.frame.DataFrame'))       
                    subfield_converted = table(field_struct.(subfields{sf}));

                else 
                    subfield_converted = double(field_struct.(subfields{sf}));
                end

                % Save this subfield into the field struct 
                field_struct.(subfields{sf}) = subfield_converted;
            end

            % Save this field in the chunk struct 
            chunk_struct.(field_names{ff}) = field_struct; 
            
        end

        % Save this converted chunk into a new cell array 
        sorted_chunks_parsed{cc} = chunk_struct; 
    end

    % Transpose to column cell 
    sorted_chunks_parsed = sorted_chunks_parsed';

end