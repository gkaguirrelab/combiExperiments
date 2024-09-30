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

%% Python environment
% Routines which interact with the lightLogger system require python, as do
% routines for the processing of fMRI data. It is necessary to create and
% configure a virtual python environment for this purpose, using the
% approach described here:
%   https://www.mathworks.com/matlabcentral/answers/1750425-python-virtual-environments-with-matlab
%
% In brief:
%   - Locate your python binary (e.g., /usr/bin/python3)
%   - Determine your python version using this terminal command:
%       /usr/bin/python3 --version 
%   - Create a virtual environment in your home directory, using (e.g.)
%     this terminal command:
%       /usr/bin/python3 -m venv /Users/username/py39
%   - Activate the environment in the terminal: source /Users/username/py39/bin/activate
%   - Use pip to install these packages:
%       python -m pip install opencv-python
%       python -m pip install numpy
%       python -m pip install matplotlib
%       python -m pip install regex
%       python -m pip install scipy
%       python -m pip install tedana
%   - Find the location of the virtual python executable by entering the
%     python environment in the terminal, and then issuing this command:
%       python
%       import sys
%       sys.executable
%       exit()
%
% A typical path that results would be "/Users/aguirre/py39/bin/python".
% Place this path string into the variable below:
myPyenvPath = ''; % <--- UPDATE THIS
if isempty(myPyenvPath)
    warning('Edit combiExperimentsLocalHook to define your python virtual environment.')
else
    pyenv('Version',myPyenvPath,'ExecutionMode','OutOfProcess');
end

end