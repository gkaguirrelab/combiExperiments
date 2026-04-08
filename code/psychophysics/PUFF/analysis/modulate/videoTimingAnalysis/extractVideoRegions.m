function [intensityData, regionMasks] = extractVideoRegions(dirStruct)
% In the modulate experiment, there is a variable delay between starting
% the stimulus modulation and the start of video recording. We can measure
% this delay by detecting the small change in image intensity introduced
% into the IR video by the 40% light flux modulation. This routine takes a
% list of raw avi video files. The user is prompted to draw two regions of
% interest. These regions should be in the partially illuminated,
% crescentic areas at the edge of each of the two eye cups. The routine
% then loops through the videos and extracts the average image intensity
% over time from each of the two regions. Examination of these time series
% measurements reveals the sinusoidal modulation of image intensity. The
% left and right eyes were recorded by separate cameras and composited into
% the single video, so there will be a slight temporal offset between the
% two regions which we can also measure.
%
% Inputs:
%   dirStruct - The structure array returned by the MATLAB 'dir' command.
%
% Outputs:
%   intensityData - [2 x N] cell array.
%                   Row 1: Region 1 vectors. Row 2: Region 2 vectors.
%   regionMasks   - [H x W x 2] logical matrix.
%                   (:,:,1) is Region 1, (:,:,2) is Region 2.
% Example use
%{
    clear;
    % Get a list of video files that are 40% LightFlux
    dataDir='/Users/aguirre/Aguirre-Brainard Lab Dropbox/Geoffrey Aguirre/BLNK_raw/PuffLight/modulate/';
    fileStructList=dir(fullfile('*/*LightFlux_contrast-0.40*avi'));
    % Call the routine
    [intensityData, regionMasks] = extractVideoRegions(fileStructList);
    % Save input and results
    saveDir='/Users/aguirre/Aguirre-Brainard Lab Dropbox/Geoffrey Aguirre/BLNK_analysis/PuffLight/modulate/videoLatencyAnalysis';
    save(fullfile(saveDir,[datestr(today) '.mat']),'fileStructList','intensityData','regionMasks');    
%}

    % 1. Filter the dir structure for files only and .avi extension
    % This handles cases where dir() might include folders or system files
    isInvalid = [dirStruct.isdir];
    fileList = dirStruct(~isInvalid);
    
    % Further filter for .avi files (case-insensitive)
    aviIdx = endsWith({fileList.name}, '.avi', 'IgnoreCase', true);
    fileList = fileList(aviIdx);

    numVideos = length(fileList);
    if numVideos == 0
        error('No .avi files found in the provided dir structure.');
    end

    intensityData = cell(2, numVideos);
    tPath = tempdir; 
    
    %% Setup Phase: Define ROIs
    % Construct absolute path for the first file
    firstVideoAVI = fullfile(fileList(1).folder, fileList(1).name);
    setupMP4 = fullfile(tPath, 'roi_setup_temp.mp4');
    
    fprintf('Step 1: Converting first video for ROI setup...\n');
    convertVideo(firstVideoAVI, setupMP4);
    
    vSetup = VideoReader(setupMP4);
    targetFrameIdx = 100;
    if vSetup.NumFrames < targetFrameIdx, targetFrameIdx = 1; end
    setupFrame = read(vSetup, targetFrameIdx);
    
    [h, w, ~] = size(setupFrame);
    regionMasks = false(h, w, 2); 
    
    fig = figure('Name', 'ROI Setup: Frame 100', 'NumberTitle', 'off');
    imshow(setupFrame);
    
    title('Select Region 1 (Red) - Double-click to finish');
    roi1 = drawpolygon(gca, 'Color', 'r'); wait(roi1);
    regionMasks(:,:,1) = createMask(roi1);
    
    title('Select Region 2 (Blue) - Double-click to finish');
    roi2 = drawpolygon(gca, 'Color', 'b'); wait(roi2);
    regionMasks(:,:,2) = createMask(roi2);
    
    close(fig);
    if exist(setupMP4, 'file'), delete(setupMP4); end

    %% Batch Processing Phase
    for i = 1:numVideos
        % Build absolute path from structure
        currentAVI = fullfile(fileList(i).folder, fileList(i).name);
        [~, vidName, ~] = fileparts(currentAVI);
        tempMP4 = fullfile(tPath, [vidName, '_processed.mp4']);
        
        fprintf('Processing Video %d/%d: %s\n', i, numVideos, vidName);
        
        try
            convertVideo(currentAVI, tempMP4);
            pause(0.2); 
            
            v = VideoReader(tempMP4);
            totalFrames = floor(v.Duration * v.FrameRate);
            
            data1 = zeros(totalFrames, 1);
            data2 = zeros(totalFrames, 1);
            fCount = 0;
            
            m1 = regionMasks(:,:,1);
            m2 = regionMasks(:,:,2);
            
            while hasFrame(v)
                fCount = fCount + 1;
                frame = readFrame(v);
                
                if size(frame, 3) == 3
                    grayFrame = double(rgb2gray(frame));
                else
                    grayFrame = double(frame);
                end
                
                data1(fCount) = mean(grayFrame(m1));
                data2(fCount) = mean(grayFrame(m2));
            end
            
            intensityData{1, i} = data1;
            intensityData{2, i} = data2;
            
        catch ME
            fprintf('   !! Error processing %s: %s\n', vidName, ME.message);
        end
        
        if exist(tempMP4, 'file'), delete(tempMP4); end
    end
    
    fprintf('\nBatch processing complete.\n');
end

%% Helper: FFmpeg Conversion
function convertVideo(inputPath, outputPath)
    cmd = sprintf('ffmpeg -y -i "%s" -c:v libx264 -crf 17 -pix_fmt yuv420p -loglevel error "%s"', ...
          inputPath, outputPath);
    [status, cmdOut] = system(cmd);
    if status ~= 0
        fprintf('FFmpeg Output: %s\n', cmdOut);
        error('FFmpeg failed.');
    end
end