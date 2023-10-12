function vidDelaySecs = calcVidDelay(obj,trialIdx)

% Path to the video file
vidOutFile = fullfile(obj.dataOutDir,sprintf([obj.filePrefix 'trial_%02d.mkv'],trialIdx));

% Check that the file exists
if ~isfile(vidOutFile)
    vidDelaySecs = nan;
else
    % Get the creation time stamp for the video file, with msec precision.
    d1 =datetime(py.os.stat(vidOutFile).st_birthtime,'ConvertFrom','epochtime','TicksPerSecond',1,'Format','dd-MM-yyyy HH:mm:ss.SSS');
    % This time is is UTC. Adjust for the current time zone
    dt = tzoffset(datetime('today','TimeZone','America/New_York'));
    d1 = d1+dt;
    % Store the difference in time between trial onset and file recording
    % onset
    vidDelaySecs = milliseconds(d1 - obj.trialData(trialIdx).recordCommandStartTime)/1000;
end

obj.trialData(trialIdx).vidDelaySecs = vidDelaySecs;


end