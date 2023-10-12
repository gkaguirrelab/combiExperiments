function deriveVideoSpectrograms(subjectID,sessionDate,varargin)
% The actual duration of each video is 53 minutes and ~20 seconds (or 3200
% seconds), as opposed to the nominal 60 minutes. Consequently, the frame
% rate is 112.5 fps, as opposed to the nominal 100 fps.
%{
subjectID = 'HERO_gka1';
sessionDate = '29-03-2023';
deriveVideoSpectrograms(subjectID,sessionDate);
%}

% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('dropBoxBaseDir',getpref('combiLEDToolbox','dropboxBaseDir'),@ischar);
p.addParameter('projectName','combiLED',@ischar);
p.addParameter('approachName','environmentalSampling',@ischar);
p.addParameter('fps',112.5,@isnumeric);
p.addParameter('windowDurFrames',1200,@isnumeric);
p.addParameter('windowStepFrames',600,@isnumeric);
p.parse(varargin{:})

% Extract some variables
fps = p.Results.fps;
windowLengthFrames = p.Results.windowDurFrames;
windowStepFrames = p.Results.windowStepFrames;

% Path to the data
dataDir = fullfile(p.Results.dropBoxBaseDir,...
    'MELA_data',...
    p.Results.projectName,...
    p.Results.approachName,...
    subjectID,sessionDate);

analysisDir = fullfile(p.Results.dropBoxBaseDir,...
    'MELA_analysis',...
    p.Results.projectName,...
    p.Results.approachName,...
    subjectID,sessionDate);

% If the analysisDir does not exist, create it
if ~isfolder(analysisDir)
    mkdir(analysisDir);
end

% Get the list of videos
videoDir = fullfile(dataDir,'videos');
videoList =dir(fullfile(videoDir,'*','*.avi'));


% Loop through the videos
for vv = 1:length(videoList)

    % Open the video object
    vidFilename = fullfile(videoList(vv).folder,videoList(vv).name);
    resultFilename = fullfile(analysisDir,[videoList(vv).name '_spectrogram.mat']);
    vObj = VideoReader(vidFilename);

    % Define the properties of the Fourier transform
    framePoints = 1:windowStepFrames:vObj.NumFrames-windowLengthFrames;
    nSamples = length(framePoints);
    vecLength = windowLengthFrames/2+1;

    % Set up some variables
    spectrogram=zeros(3,nSamples,vecLength);
    luminanceVec = [];

    % Loop over the time samples.
    for ii=1:nSamples
        startFrame = framePoints(ii);
        % Check if we can use a portion of the last loaded video snippet
        if ii<4
            video = read(vObj,[startFrame,startFrame+windowLengthFrames-1]);
            % Trim the top 10 frames that have the time code
            % and get the average
            video = video(11:end,:,:,:);
        else
            lastStart = framePoints(ii-1);
            lastEnd = lastStart+windowLengthFrames-1;
            video(:,:,:,1:windowLengthFrames-windowStepFrames) = video(:,:,:,1+windowStepFrames:end);
            newVidSeg = read(vObj,[lastEnd+1,lastEnd+windowStepFrames]);
            video(:,:,:,windowLengthFrames-windowStepFrames+1:end) = newVidSeg(11:end,:,:,:);
        end

        % Get the dimensions of the video
        xDim = size(video,1);
        yDim = size(video,2);
        cDim = size(video,3);
        tDim = size(video,4);

        % Linearize the video
        videoVec = reshape(permute(video,[1 2 4 3]),xDim*yDim,tDim,cDim);

        % Collapse the space dimension
        meanSpaceVec = squeeze(mean(videoVec,1));
        backgroundPrimary = mean(meanSpaceVec);

        % Convert from RGB to approximate LMS
        modulationReceptors = cameraToCones(meanSpaceVec-backgroundPrimary);

        % Get the isomerizations of the LMS receptors for the mean (space
        % and time) RGB values of this vector. This is the background for
        % the contrast calculations
        backgroundReceptors = cameraToCones(mean(meanSpaceVec));

        % Get the contrast at each point in time on the LMS photoreceptors,
        % relative to the background
        contrastReceptors = modulationReceptors ./ backgroundReceptors;

        % Break out the contrastReceptors into separate variables to clean
        % up the following code
        Lcone = contrastReceptors(:,1);
        Mcone = contrastReceptors(:,2);
        Scone = contrastReceptors(:,3);

        % Loop through the post-receptoral directions and obtain the FFT
        for pp=1:3
            switch pp
                case 1
                    signal = (Lcone+Mcone)/2;
                    luminanceVec = [luminanceVec,signal];
                case 2
                    signal = Lcone - Mcone;
                case 3
                    signal = Scone - (Lcone+Mcone)/2;

            end
            % Get the FFT
            [frq,amp] = simpleFFT(signal,fps);
            spectrogram(pp,ii,:) = amp;
        end

    end % Loop over the time samples

    % Save this spectrogram
    save(resultFilename,'spectrogram','luminanceVec','frq');

end % Loop over the videos


end % Function
