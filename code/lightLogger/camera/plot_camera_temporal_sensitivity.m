function plot_camera_temporal_sensitivity(TTF_info_path)
% Plot the TTF of the camera from the recordings made with collect_camera_temporal_sensitivity_measurements. 
%
% Syntax:
%   plot_camera_temporal_sensitivty(recordings_dir, experiment_filename)
%
% Description:
%   Generates a temporal sensitivity plot of the camera using data 
%   from a given TTF_info struct. 
%
% Inputs:
%   TTF_info_path        - String. Represents the path to a TTF_info struct  
%
% Outputs:
%   NONE
%
% Examples:
%{
    TTF_info_path = '/Users/zacharykelly/Aguirre-Brainard Lab Dropbox/Zachary Kelly/FLIC_admin/Equipment/SpectacleCamera/calibration/graphs/TTF_info.mat'; 
    plot_camera_temporal_sensitivity(TTF_info_path);
%}
    % Parse and validate the inputs 
    parser = inputParser;

    parser.addRequired("TTF_info_path", @(x) ischar(x) || isstring(x)); % Ensure the TTF_info_path is a string type 

    parser.parse(TTF_info_path);

    TTF_info_path = parser.Results.TTF_info_path; 

    % Read in the TTF info path
    TTF_info = load(TTF_info_path).TTF_info; 

    disp(TTF_info)


end