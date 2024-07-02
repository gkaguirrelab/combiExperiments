function fit_calibration(MSCalDataFiles)
    loaded_data_files = {};

    % Load all of the data files 
    for ii = 1:numel(MSCalDataFiles)
        loaded_data_files{ii,1} = load(MSCalDataFiles{ii});
        loaded_data_files{ii,2} = loaded_data_files{ii,1}.meta.cal; % need to add the load wrapper here
    end


    % move this to object oriented 
    % pass in cell array of paths to the minispect
    % result of MSCalData files
    % fitting routine loads each of these 
    % also loads spectral sensitivity functions for the minispect 
    % from each of the MSCalData files, extract the sphere (source) calibration file
    % now we have the raw materials to do the fit


    % do 3 reps of calibration and save mat file


end