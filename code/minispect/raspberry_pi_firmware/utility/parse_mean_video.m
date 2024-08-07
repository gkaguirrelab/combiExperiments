function video_arr = parse_mean_video(path_to_video, pixel_array)
%{
This script is a MATLAB wrapper for the parse_video
function in Camera_util.py that allows for reading the 
returned value of an .AVI file parsed into an array 
into MATLAB memory. Pixel array is 0 indexed
%}

% Ensure we are using a MATLAB compatible Python version
% only run this once ever. Will throw an error if you try to run again
%pyversion('/Library/Frameworks/Python.framework/Versions/3.10/bin/python3'); 

% If pixel_array is None, set it to an empty array 
if(nargin < 2)
    pixel_array = [];
else % Otherwise, convert MATLAB 1-indexing to Python 0-indexing
    pixel_array = pixel_array - 1; 
end 

% Import the module
curr_dir = cd();
module_dir = fileparts(mfilename('fullpath'));
cd(module_dir);
Camera_util = py.importlib.import_module('Camera_util');
cd(curr_dir);

% Convert the pixels MAT array to Python numpy array
pixels_as_numpy = py.numpy.array(pixel_array, pyargs('dtype', 'int'));

% Retrieve the video of mean frames spliced by pixels 
video_arr = uint8(Camera_util.parse_mean_video(path_to_video, pixels_as_numpy));

end