function flickerR01LocalHook

%  flickerR01LocalHook
%
% As part of the setup process, ToolboxToolbox will copy this file to your
% ToolboxToolbox localToolboxHooks directory (minus the "Template" suffix).
% The defalt location for this would be
%   ~/localToolboxHooks/flickerR01LocalHook.m
%
% Each time you run tbUseProject('flickerR01'), ToolboxToolbox will
% execute your local copy of this file to do setup.
%
% You should edit your local copy with values that are correct for your
% local machine, for example the output directory location.
%


% Say hello.
projectName = 'flickerR01';

% Delete any old prefs
if (ispref(projectName))
    rmpref(projectName);
end

% Handle hosts with custom dropbox locations
[~, userName] = system('whoami');
userName = strtrim(userName);
switch userName
    case 'aguirre'
        dropBoxUserFullName = 'Geoffrey Aguirre';
        dropboxBaseDir = fullfile(filesep,'Users',userName,...
            'Aguirre-Brainard Lab Dropbox',dropBoxUserFullName);
    otherwise
        dropboxBaseDir = ...
            fullfile('/Users', userName, ...
            'Aguirre-Brainard Lab Dropbox',userName);
end

% Set preferences for project output
setpref(projectName,'dropboxBaseDir',dropboxBaseDir); % main directory path 

end