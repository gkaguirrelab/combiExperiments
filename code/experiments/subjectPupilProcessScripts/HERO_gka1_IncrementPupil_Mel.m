%% pupilVideos
%
% The video analysis pre-processing pipeline for a MELA folder of videos.
%
% To define mask bounds, use:
%{
	glintFrameMask = defineCropMask('trial_01.mov','startFrame',10)
	pupilFrameMask = defineCropMask('trial_03.mov','startFrame',10)
%}
% For the glint, put a tight box around the glint. For the pupil, define a
% mask area that safely contains the pupil at its most dilated.

%% Session parameters

% Subject and session params.
pathParams.Subject = 'test';
pathParams.dataDir = '/Users/aguirre/Aguirre-Brainard Lab Dropbox/Geoffrey Aguirre/MELA_data/combiLED/HERO_gka1/IncrementPupil/Mel/2024-02-29';
pathParams.analysisDir = '/Users/aguirre/Aguirre-Brainard Lab Dropbox/Geoffrey Aguirre/MELA_analysis/combiLED/HERO_gka1/IncrementPupil/Mel/2024-02-29';


%% Analysis Notes

%% Videos

videoNameStems = {};

for ii = 1:15

     videoNameStems{ii} = sprintf('trial_%02d',ii);
    
end

% Mask bounds, pupil Frame mask defined in the loop as it is different for
% different videos.
glintFrameMask = [195   318   399   778];
pupilFrameMask = [167   743   256   396];

% Pupil settings
pupilCircleThreshSet = 0.004;
pupilRangeSets = [20 40];
adaptivePupilRangeFlag = false;
ellipseEccenLBUB = [0 1];
ellipseAreaLB = 500;
ellipseAreaUP = 25000;
pupilGammaCorrection = 0.5;
maskBox = [20 30];
nOtsu = 3;

% Glint settings
glintPatchRadius = 45;
glintThreshold = 0.4;

% Control stage values (after the 3th before the 6th stage)
% Cut settings: 0 for buttom cut, pi/2 for right, pi for top, 3*pi/2 for
% left
candidateThetas = [pi,5*pi/4,3*pi/2];
minRadiusProportion = 0.4;
cutErrorThreshold = 2; % 0.25 old val

%% Loop through video name stems get each video and its corresponding masks
for ii = 1:15
    
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
        'nOtsu',nOtsu,...
        'glintThreshold',glintThreshold,...
        'pupilFrameMask',pupilFrameMask,...
        'adaptivePupilRangeFlag',adaptivePupilRangeFlag,...
        'pupilRange',pupilRange,...
        'maskBox',maskBox,...
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

