function storeTrial(obj,vepDataStruct,trialLabel)

% Define the save location
dataOutFile = fullfile(obj.dataOutDir,sprintf([obj.filePrefix trialLabel 'stim_%02d.mat'],obj.trialIdx));

% Save the data
save(dataOutFile,'vepDataStruct');

% Alert the user
if obj.verbose
    fprintf('done.\n');
end

% Update the trialData
obj.trialData(obj.trialIdx).startTime = vepDataStruct.startTime;

% Iterate the trial index
obj.trialIdx = obj.trialIdx+1;

end