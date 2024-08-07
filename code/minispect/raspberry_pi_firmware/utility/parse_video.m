function video_arr = parse_video(path_to_video)

%{
This script is a MATLAB wrapper for the parse_video
function in Camera_util.py that allows for reading the 
returned value of an .AVI file parsed into an array 
into MATLAB memory. 
%}

% Ensure we are using a MATLAB compatible Python version
% only run this once ever. Will throw an error if you try to run again
%pyversion('/Library/Frameworks/Python.framework/Versions/3.10/bin/python3'); 

% Add the module to the Python path if not there already
module_path = '~/Documents/MATLAB/projects/combiExperiments/code/minispect/raspberry_pi_firmware/utility';
if count(py.sys.path, module_path) == 0
    insert(py.sys.path, int32(0), module_path);
end

% Import the module
Camera_util = py.importlib.import_module('Camera_util');

video_arr = Camera_util.parse_video(path_to_video); 

end