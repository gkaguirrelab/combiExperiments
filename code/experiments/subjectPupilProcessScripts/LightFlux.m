%% pupilVideos
%
% The video analysis pre-processing pipeline for a MELA folder of videos.
%
% To define mask bounds, use:
%{
	glintFrameMask = defineCropMask('pupil_L+S_01.mov','startFrame',10)
	pupilFrameMask = defineCropMask('pupil_L+S_01.mov','startFrame',10)
%}
% For the glint, put a tight box around the glint. For the pupil, define a
% mask area that safely contains the pupil at its most dilated.

%% Session parameters

% Subject and session params.
pathParams.Subject = 'LightFlux';

%% Analysis Notes

%% Videos

% BREAKS: 1:10, 11:49, 99:147

% % 4.0 freq vids
% vids = [2,10,16,23,35,36,47,51,59,65,72,84,85,96,100,108,114,121,133,134,145];

% % 6.0 freq vids
% vids = [7,8,18,25,32,37,46,56,57,67,74,81,86,95,105,106,116,123,130,135,144];

% % 10.0 freq vids
% vids = [5,14,15,27,31,38,48,54,63,64,76,80,87,97,103,112,113,125,129,136,146];

% % 14.0 freq vids
% vids = [1,12,19,24,30,40,49,50,61,68,73,79,89,98,99,110,117,122,128,138,147];

% % 20.0 freq vids
% vids = [4,9,17,28,29,41,44,53,58,66,77,78,90,93,102,107,115,126,127,139,142];

% % 28.0 freq vids
% vids = [3,13,21,22,33,39,45,52,62,70,71,82,88,94,101,111,119,120,131,137,143];

% % 40.0 freq vids
% vids = [6,11,20,26,34,42,43,55,60,69,75,83,91,92,104,109,118,124,132,140,141];

videoNameStems = {};

for ii = 1:70
    
    if ismember(ii,[2,10,16,23,35,36,47,51,59,65])
        ss = 'freq_3.0';
    elseif ismember(ii,[7,8,18,25,32,37,46,56,57,67])
        ss = 'freq_4.7';
    elseif ismember(ii,[5,14,15,27,31,38,48,54,63,64])
        ss = 'freq_7.5';
    elseif ismember(ii,[1,12,19,24,30,40,49,50,61,68])
        ss = 'freq_11.7';
    elseif ismember(ii,[4,9,17,28,29,41,44,53,58,66])
        ss = 'freq_18.5';
    elseif ismember(ii,[3,13,21,22,33,39,45,52,62,70])
        ss = 'freq_29.2';
    elseif ismember(ii, [6,11,20,26,34,42,43,55,60,69])
        ss = 'freq_46.0';
    end
    
    if ii < 10
        vidName = [ss '_trial_0' num2str(ii)];
    else
        vidName = [ss '_trial_' num2str(ii)];
    end
    videoNameStems{end+1} = vidName;
    
end

% Mask bounds, pupil Frame mask defined in the loop as it is different for
% different videos.
glintFrameMask = [318 37 120 617];
pupilFrameMask = [322 205 97 439];

% Pupil settings
pupilCircleThreshSet = 0.004;
pupilRangeSets = [30 40];
ellipseEccenLBUB = [0.2 2];
ellipseAreaLB = 0;
ellipseAreaUP = 90000;

% Glint settings
glintPatchRadius = 45;
glintThreshold = 0.4;

% Control stage values (after the 3th before the 6th stage)
% Cut settings: 0 for buttom cut, pi/2 for right, pi for top, 3*pi/4 for
% left
candidateThetas = pi;
minRadiusProportion = 0.8;
cutErrorThreshold = 5;
pupilGammaCorrection = 0.40;

vids = 70:70;
%% Loop through video name stems get each video and its corresponding masks
for ii = vids

    if ii > 50
        pupilRangeSets = [40 55];
    end

    pupilCircleThresh = pupilCircleThreshSet;
    pupilRange = pupilRangeSets;
    videoName = {videoNameStems{ii}};
    % Analysis parameters
    % To adjust these parameters for a given session, use the utility:
    %{
        estimatePipelineParamsGUI('','TOME')
    %}
    % And select one of the raw data .mov files.

    sessionKeyValues = {...
        'pupilGammaCorrection', pupilGammaCorrection, ...
        'startFrame',1, ...
        'nFrames', Inf, ...
        'glintFrameMask',glintFrameMask,...
        'glintGammaCorrection',0.75,...
        'glintThreshold',glintThreshold,...
        'pupilFrameMask',pupilFrameMask,...
        'pupilRange',pupilRange,...
        'pupilCircleThresh',pupilCircleThresh,...
        'glintPatchRadius',glintPatchRadius,...
        'candidateThetas',candidateThetas,...
        'cutErrorThreshold',cutErrorThreshold,...
        'radiusDivisions',50,...
        'ellipseTransparentLB',[0,0,ellipseAreaLB, ellipseEccenLBUB(1), 0],...
        'ellipseTransparentUB',[1280,720,ellipseAreaUP,ellipseEccenLBUB(2), pi],...
        'minRadiusProportion', minRadiusProportion,...
        };

    % Call the pre-processing pipeline
    melaPupilPipeline(pathParams,videoName,sessionKeyValues);
    
end

