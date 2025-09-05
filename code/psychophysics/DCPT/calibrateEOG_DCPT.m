function calibrateEOG_DCPT(subjectID, sessionNumber)

% Examples:
%{
    subjectID = 'FLIC_0018';
    sessionNumber = 1;
    calibrateEOG_DCPT(subjectID, sessionNumber)
%}

% Open the connection to the LabJack
EOGControl = BiopackControl('');

% Load and play the audio file
% There is a two second pause before the voice begins to allow for EOG
% startup, and 0.25 seconds between each command
[y, Fs] = audioread('/Users/flicexperimenter/Documents/MATLAB/projects/combiExperiments/code/experiments/EOGCalInstructions.mp3');
sound(y, Fs);  % Play it back

audioStartTime = cputime();

EOGControl.trialDurationSecs = 25; % Set EOG duration
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

% Plot the session data
figure;
plot(sessionData.EOGData.timebase,sessionData.EOGData.response);
xlabel('Time (seconds)');
ylabel('Amplitude');

% Saving the plot
plotName = ['EOGSession' num2str(sessionNumber) 'CalPlot.jpg'];
plotPath = fullfile(EOGDir, plotName);
saveas(gcf, plotPath); 

end

