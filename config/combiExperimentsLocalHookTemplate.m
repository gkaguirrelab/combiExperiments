function combiExperimentsLocalHook

%  combiExperimentsLocalHook
%
% As part of the setup process, ToolboxToolbox will copy this file to your
% ToolboxToolbox localToolboxHooks directory (minus the "Template" suffix).
% The defalt location for this would be
%   ~/localToolboxHooks/combiExperimentsLocalHook.m
%
% Each time you run tbUseProject('combiExperiments'), ToolboxToolbox will
% execute your local copy of this file to do setup.
%
% You should edit your local copy with values that are correct for your
% local machine, for example the output directory location.
%


% Say hello.
projectName = 'combiExperiments';

% Delete any old prefs
if (ispref(projectName))
    rmpref(projectName);
end

% Get the DropBox path
if ismac
    dbJsonConfigFile = '~/.dropbox/info.json';
    fid = fopen(dbJsonConfigFile);
    raw = fread(fid,inf);
    str = char(raw');
    fclose(fid);
    val = jsondecode(str);
    dropboxBaseDir = val.business.path;
else
    error('Need to set up DropBox path finding for non-Mac machine')
end

% Set the prefs
setpref(projectName,'dropboxBaseDir',dropboxBaseDir); % main directory path 

% Set the default cal directory to the current project
calLocalData = fullfile(tbLocateProjectSilent(projectName),'cal');
setpref('combiLEDToolbox','CalDataFolder',calLocalData);

%% Check for required Matlab toolboxes and add-ons
% The set of Matlab add-on toolboxes being used can be determined by
% running various functions, followed by the license function.
%{
    license('inuse')
%}
% This provides a list of toolbox license names. In the following
% assignment, the license name is given in the comment string after the
% matching version name for each toolbox.
requiredAddOns = {...
    'SSH/SFTP/SCP For Matlab (v2)',...                  % optimization_toolbox
    };
% Given this hard-coded list of add-on toolboxes, we then check for the
% presence of each and issue a warning if absent.
addons = matlab.addons.installedAddons;
VName = addons{:,1};
warnState = warning();
warning off backtrace
for ii=1:length(requiredAddOns)
    if ~any(strcmp(VName, requiredAddOns{ii}))
        warnString = ['The Matlab ' requiredAddOns{ii} ' is missing. ' projectName ' may not function properly.'];
        warning('localHook:requiredMatlabToolboxCheck',warnString);
    end
end
warning(warnState);

% Configure the python environment. Note that we need to have installed:
%
%   opencv-python, numpy, matplotlib, regex, scipy, paramiko
%
% To do so, in the console we went to the location of the python executable
% and used pip install commands such as: "./python pip3 install
% opencv-python"
%
% We also ran into an issue that numpy errored when we first attempted to
% call our python module. The solution to this was to install the openblas
% C libraries using "brew install openblas".
pyenv(Version='/usr/local/bin/python3.10');

end