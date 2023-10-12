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
pathParams.Subject = 'LminusM_LMSNull';

%% Analysis Notes

%% Videos

videoNameStems = {};

for ii = 1:20
    
    if ismember(ii,[2,10,16])
        ss = 'freq_1.0';
    elseif ismember(ii,[7,8,18])
        ss = 'freq_3.0';
    elseif ismember(ii,[5,14,15])
        ss = 'freq_5.0';
    elseif ismember(ii,[1,12,19])
        ss = 'freq_8.0';
    elseif ismember(ii,[4,9,17])
        ss = 'freq_12.0';
    elseif ismember(ii,[3,13])
        ss = 'freq_16.0';
    elseif ismember(ii,[6,11,20])
        ss = 'freq_24.0';
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
glintFrameMask = [333    30   143   619];

% Pupil settings
pupilCircleThreshSet = 0.004;
pupilRangeSets = [40 50];
ellipseEccenLBUB = [0.2 2];
ellipseAreaLB = 0;
ellipseAreaUP = 90000;

% Glint settings
glintPatchRadius = 45;
glintThreshold = 0.4;

% Control stage values (after the 3th before the 6th stage)
% Cut settings: 0 for buttom cut, pi/2 for right, pi for top, 3*pi/4 for
% left
candidateThetas = 0;
minRadiusProportion = 0.8;
cutErrorThreshold = 10; % 0.25 old val

vids = 1:20;
%% Loop through video name stems get each video and its corresponding masks
for ii = vids
    % Adjustments
    if ii > 10
        pupilFrameMask = [320   323   142   355];
        if isequal(ii, 19)
            pupilFrameMask = [341   295    93   345];
        end
    else
        pupilFrameMask = [309   242    97   397];
    end
    if isequal(ii, 4)
        pupilGammaCorrection = 0.35;
    else
        pupilGammaCorrection = 0.45;
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

