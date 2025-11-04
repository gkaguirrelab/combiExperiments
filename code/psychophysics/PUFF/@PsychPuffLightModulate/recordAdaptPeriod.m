function recordAdaptPeriod(obj,recordLabel,recordDurSecs)

% Handle verbosity
if obj.verbose
    fprintf([recordLabel '...']);
end

% Get the current adapt index
currAdaptIdx = obj.adaptIdx;

% Get the current time
dateTimeVal = datetime('now','Format','yyyy-MM-dd HH:mm:ss.SSSSSS');

% If not simulating
if ~obj.simulateStimuli

    % Get the ir camera ready to record.
    obj.irCameraObj.durationSecs = recordDurSecs;
    obj.irCameraObj.prepareToRecord(recordLabel);

    % Define a stop time.
    stopTimeSeconds = cputime() + recordDurSecs;

    % Start the ir camera recording
    obj.irCameraObj.startRecording(recordLabel);

    % Wait until the video recording file has closed
    obj.irCameraObj.checkFileClosed;

    % Wait until the trial has ended
    obj.waitUntil(stopTimeSeconds);

end

% Finish the line of text output
if obj.verbose
    fprintf('done\n');
end

% Get the adapt data
adaptData = obj.adaptData;

% Store the adapt data
adaptData(currAdaptIdx).dateTimeVal = dateTimeVal;
adaptData(currAdaptIdx).recordLabel = recordLabel;
adaptData(currAdaptIdx).recordDurSecs = recordDurSecs;

% Put adaptData into the obj
obj.adaptData = adaptData;

% Increment the adapt index
obj.adaptIdx = currAdaptIdx + 1;

end