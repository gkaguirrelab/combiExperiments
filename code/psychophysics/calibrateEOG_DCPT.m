function calibrateEOG_DCPT(subjectID, sessionNumber)

% Open the connection to the LabJack
EOGControl = BiopackControl('');

% Load and play the audio file
% There is a one second pause before the voice begins to allow for EOG
% startup, and two seconds between each "Look" command
[y, Fs] = audioread('/Users/flicexperimenter/Documents/MATLAB/projects/combiExperiments/code/experiments/EOGCalInstructions.m4a');
sound(y, Fs);  % Play it back

audioStartTime = cputime();

EOGControl.trialDurationSecs = 45; % Set EOG duration
% Start recording
EOGStartTime = cputime();
[EOGData] = EOGControl.recordTrial();

endTime = cputime();

% Save everything into a struct
sessionData = struct();
sessionData.audio = y;
sessionData.Fs = Fs;
sessionData.audioStartTime = audioStartTime;
sessionData.EOGControl = EOGControl;
sessionData.EOGStartTime = EOGStartTime;
sessionData.EOGData = EOGData;
sessionData.endTime = endTime;

% Get directory info
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');
dropBoxSubDir = 'FLIC_data';
projectName = 'combiLED';
folderName = 'EOGCalibration';

% Define the EOG data directory
EOGDir = fullfile(...
    dropBoxBaseDir,...
    dropBoxSubDir,...
    projectName,...
    subjectID, ...
    folderName);

% Create the folder if it doesn't exist 
dataDir = fullfile(EOGDir);
if ~isfolder(dataDir)
    mkdir(dataDir)
end

% Define the full path to the EOG cal file
fileName = ['EOGSession' num2str(sessionNumber) 'Cal.mat'];
fullPath = fullfile(EOGDir, fileName);

% Save the session data struct to a .mat file
save(fullPath, 'sessionData');

end

