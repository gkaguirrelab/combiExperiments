function signal = parse_mean_frame_array_buffer(frame_buffers, start_buffer, pixel_indices)

    % Define types and default values of arguments
    arguments
        % Frame buffers can either be a path to a folder with frame buffers OR a vector of frame buffer paths
        frame_buffers (1,:) {mustBeCellOrString}
                                        
        % Start buffer is the buffer to start splicing from
        start_buffer (1,1) {mustBeInteger} = 0;

        % Pixel indices are the indices of which to average for each frame
        pixel_indices (1,0) {mustBeVector} = []; 

    end

    % Import the Python utility library

    file_directory = fileparts(mfilename('fullpath')); % First, save the directory where this file is. 

    camera_dir = fullfile(fileparts(file_directory), 'camera'); % Then, construct the path to the camera directory, where the camera utility functions live 

    cd(camera_dir) % CD into the camera directory so we can import the Camera utility library

    Camera_util = py.importlib.import_module('Camera_util');  % import the camera utility library 

    cd(file_directory) % return to the original directory 

    % Convert the arguments to Python types 

    % If we have a cell array of paths, convert to Python list of paths 
    if(iscell(frame_buffers))
        frame_buffers = py.list(frame_buffers);
    
    % Otherwise, if we have a string type that is a path to frame buffers, convert to Python 
    % string 
    else
        frame_buffers = py.str(frame_buffers);

    end

    % Converting start_buffer is easy as it must be an integer 
    start_buffer = py.int(start_buffer);

    % If no specific pixels are chosen, simply set pixel 
    % indices to None (NULL)
    if(isempty(pixel_indices))
        pixel_indices = py.None; 

    % Otherwise, convert to np.ndarray
    else
        pixel_indices = py.numpy.array(pixel_indices);

    end

    % Parse the buffers via Python and return them as MATLAB vector (original return type is np.array)
    signal = double(Camera_util.parse_mean_frame_array_buffer(frame_buffers, start_buffer, pixel_indices));

end


% Custom Validation function for the frame buffer argument 
function mustBeCellOrString(x) 
    if(~(iscell(x) || isstring(x)))
        error('Input [frame_buffer] must be either a cell or a string type.')
    end

end