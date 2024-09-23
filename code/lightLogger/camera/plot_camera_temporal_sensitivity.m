function plot_camera_temporal_sensitivity(TTF_info_path)
% Plot the TTF of the camera from the recordings made with collect_camera_temporal_sensitivity_measurements. 
%
% Syntax:
%   plot_camera_temporal_sensitivty(recordings_dir, experiment_filename)
%
% Description:
%   Generates a temporal sensitivity plot of the camera using data 
%   from a given experiment_filename located in recordings_dir. 
%
% Inputs:
%   recordings_dir        - String. Represents the path to the directory
%                           where camera recordings are stored     
%
%   experiment_filename   - String. Represents the name of the experiment
%                           whose videos we will use to generate the TTF  
%
% Outputs:
%   NONE
%
% Examples:
%{
    
    plot_camera_temporal_sensitivity_measurements(fullfile(calDir,calFileName), output_filename);
%}
    % Parse and validate the inputs 
    parser = inputParser;

    parser.addRequired("TTF_info_path", @(x) ischar(x) || isstring(x)); % Ensure the TTF_info_path is a string type 

    parser.parse(TTF_info_path);

    TTF_info_path = parser.Results.TTF_info_path; 

end