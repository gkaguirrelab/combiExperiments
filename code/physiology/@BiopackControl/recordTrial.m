function [vepDataStruct] = recordTrial(obj)

% Alert the user
if obj.verbose
    fprintf('starting trial %d...',obj.trialIdx)
end

% Initialize the vep Data Struct
vepDataStruct.startTime = datetime;

% Record the EEG. We place the recording in a try-catch block as mysterious
% errors can occur in LabJack land.
if ~obj.simulateResponse
    try
        % Acquire the data
        tic;
        obj.labjackOBJ.startDataStreamingForSpecifiedDuration(obj.trialDurationSecs);
        elapsedTimeSecs = toc;
        % Place the data in a response structure
        vepDataStruct.timebase = obj.labjackOBJ.timeAxis;
        vepDataStruct.response = obj.labjackOBJ.data';
        vepDataStruct.elapsedTimeSecs = elapsedTimeSecs;
    catch err
        % Close up shop
        labjackOBJ.shutdown();
        rethrow(err)
    end % try-catch
else
    nSamples = obj.recordingFreqHz*obj.trialDurationSecs;
    vepDataStruct.timebase = linspace(0,obj.trialDurationSecs,nSamples);
    vepDataStruct.response = rand(1,nSamples);
    vepDataStruct.elapsedTimeSecs = obj.trialDurationSecs;
    pause(obj.trialDurationSecs);
end


end