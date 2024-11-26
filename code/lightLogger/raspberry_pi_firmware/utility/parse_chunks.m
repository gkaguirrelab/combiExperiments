function sorted_chunks_parsed = parse_chunks(path_to_experiment)
% Parse the chunks of a chunked recording by reading in each chunk's data 
% and converting it all to native MATLAB types. 
%
% Syntax:
%   [AS_t, TS_t, LS_t, temp_t] = readInMSDataFiles(path_to_readings)
%
% Description:
%   Reads in the chunks from an experiment and all of their
%   associated data, first parsing their paths, 
%   then loading in all of the data from those paths and converting 
%   them to native MATLAB types. 
%
%
% Inputs:
%   path_to_experiment    - String. The path to the suprafile 
%                           containing all of the chunks.
%
%
% Outputs:
%
%   sorted_chunks_parsed  - Cell. A cell containing structs 
%                           of all of the sensors' data 
%                           for a given chunk.  
%
% Examples:
%{
    path_to_readings = './results';
    sorted_chunks_parsed = parse_chunks(path_to_experiment)
%}

    % Parse and validate the input arguments
    arguments 
        path_to_experiment {mustBeText}; % The path to the suprafolder for this experiment

    end

    % First, retrieve the chunks and their sorted paths
    sorted_chunks_unparsed = parse_chunk_paths(path_to_experiment);

    % Next, we will iterate over the chunks, reading their data in
    % and turning them into MATLAB types 
    for cc = 1:numel(sorted_chunks_unparsed)
        fprintf('Parsing chunk %d/%d\n', cc, numel(sorted_chunks_unparsed));

        % First, we will retrieve the the chunk 
        chunk_info_struct = sorted_chunks_unparsed{cc}; 

        % Next, we must read in and convert their types to MATLAB types 
        ms_path = chunk_info_struct.MS; 
        pupil_path = chunk_info_struct.Pupil;
        world_path = chunk_info_struct.World; 
        world_FPS_path = chunk_info_struct.WorldFPS; 
        sunglasses_path = chunk_info_struct.Sunglasses;

        % Read in the MS path as a cell of tables from each of the sensors
        if(ms_path ~= "")
            chunk_info_struct.MS = readInMSDataFiles(ms_path);
        end 

        % Read in the pupil camera as a numpy array
        if(pupil_path ~= "")
            chunk_info_struct.Pupil = parse_mean_frame_array_buffer(pupil_path);
        end 

        % Read in the world camera as a numpy array
        if(world_path ~= "")
            chunk_info_struct.World = parse_mean_frame_array_buffer(world_path);
        end

        % Read in the world FPS information
        if(world_FPS_path ~= "")
            world_FPSdatafile = py.open(world_FPS_path, 'rb'); 
            world_FPSdata = struct(py.pickle.load(world_FPSdatafile));
            world_FPSdata.num_frames_captured = double(world_FPSdata.num_frames_captured);
            world_FPSdatafile.close(); 

            chunk_info_struct.WorldFPS = world_FPSdata; 
        end

        % Read in the sunglasses 
        if(sunglasses_path ~= "")
            chunk_info_struct.Sunglasses = readtable(sunglasses_path, 'ReadVariableNames', false);
        end 

        % Append the parsed chunk to an implicit cell array
        sorted_chunks_parsed{cc} = chunk_info_struct;

    end

end