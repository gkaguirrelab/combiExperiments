function convertedStruct = pyDictToStruct(pyDict)
% Recursively convert a Python dictionary entirely to MATLAB types.
%
% Syntax:
%   convertedStruct = pyDictToStruct(originalStruct)
%
% Description:
%   Recursively convert a Python dictionary object 
%   to MATLAB types. Will throw an error for an unsupported
%   Python type for conversion. 
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
    % Make an initial struct conversion
    originalStruct = struct(pyDict);

    % Go over all of the fields and convert them as necessary too
    fields_of_struct = fieldnames(originalStruct);

    % Initialize the convertedStruct variable 
    convertedStruct = struct();

    % Iterate over the fields of the struct
    for ff = 1:numel(fields_of_struct)
        % Retrieve the field name
        fieldName = fields_of_struct{ff};
        fieldValue = originalStruct.(fieldName);

        fprintf('Converting field %s of class %s\n', fieldName, class(fieldValue));

        % Check if the field is any standardized type that does not need complex conversion
        if(is_basic_type(fieldValue))
            convertedStruct.(fieldName) = double(fieldValue);
        
        % Check for more complex types. For instance, it could be a list of dictionaries
        elseif(is_complex_type(fieldValue))
            convertedStruct.(fieldName) = pyListToCell(fieldValue);

        % Check if the field is a py.dict (most complex type)
        elseif isa(fieldValue, 'py.dict')
            convertedStruct.(fieldName) = pyDictToStruct(originalStruct.(fieldName));
        
        % Throw an error if it is an unsupported type
        else 
            fprintf('Field Name: %s | Class: %s\n', fieldName, class(fieldValue));
            error_message = sprintf('ERROR: %s is of unsupported conversion type of class: %s.', fieldName, class(fieldValue)); 
            error(error_message);
        end

    end

    % Utility functions 
    
    % Check if the given element is an easily convertible type
    function is_basic = is_basic_type(object)
        easily_convertible_types = {'py.int', 'py.float', 'py.numpy.ndarray'};

        if(ismember(class(object), easily_convertible_types))
            is_basic = true; 
            return ;
        end 

        is_basic = false; 
        return; 
    end

    % Check if the given element is a more complex iterable type
    function is_complex = is_complex_type(object)
        more_complex_types = {'py.list', 'py.tuple'};

        if(ismember(class(object), more_complex_types))
            is_complex = true;
            return ; 
        end 

        is_complex = false; 
        return; 
    end


    % Recursively convert a list type to a MATLAB cell array
    function converted_list = pyListToCell(pyList)
        % First, convert the whole thing to a cell array 
        converted_list = cell(pyList);

        % Then, iterate over the elements
        for ii = 1:numel(converted_list)
            % Retrieve the element of at index ii
            element = converted_list{ii}; 

            % If it is a basic type, simply convert to double 
            if(is_basic_type(element)) 
                converted_list{ii} = double(element);
            
            % If it is another list, we need to recurse
            elseif(is_complex_type(element))
                converted_list{ii} = pyListToCell(element);
            
            % If it's another dictionary, call the dictionary parser again
            elseif(isa(element, 'py.dict'))
                converted_list{ii} = pyDictToStruct(element);
            
            % Throw an error if it's an unsupported type
            else
                disp(element)
                error_message = sprintf('ERROR: Unsupported conversion type of class: %s.', class(element)); 
                error(error_message);
            end 
        end
    end 



end