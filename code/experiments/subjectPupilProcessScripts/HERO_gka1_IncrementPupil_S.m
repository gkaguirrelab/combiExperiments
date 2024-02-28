%% pupilVideos
%
% The video analysis pre-processing pipeline for a MELA folder of videos.
%
% To define mask bounds, use:
%{
	glintFrameMask = defineCropMask('trial_01.mov','startFrame',10)
	pupilFrameMask = defineCropMask('trial_01.mov','startFrame',10)
%}
% For the glint, put a tight box around the glint. For the pupil, define a
% mask area that safely contains the pupil at its most dilated.

%% Session parameters

% Subject and session params.
pathParams.Subject = 'test';
pathParams.dataDir = '/Users/aguirre/Aguirre-Brainard Lab Dropbox/Geoffrey Aguirre/MELA_data/combiLED/HERO_gka1/IncrementPupil/SnoMel/2024-02-28';
pathParams.analysisDir = '/Users/aguirre/Aguirre-Brainard Lab Dropbox/Geoffrey Aguirre/MELA_analysis/combiLED/HERO_gka1/IncrementPupil/SnoMel/2024-02-28';


%% Analysis Notes

%% Videos

videoNameStems = {};

for ii = 1:20

     videoNameStems{ii} = sprintf('trial_%02d',ii);
    
end

% Mask bounds, pupil Frame mask defined in the loop as it is different for
% different videos.
glintFrameMask = [364   410   222   716];
pupilFrameMask = [160   710   192   394];

% Pupil settings
pupilCircleThreshSet = 0.004;
pupilRangeSets = [20 40];
adaptivePupilRangeFlag = false;
ellipseEccenLBUB = [0 1];
ellipseAreaLB = 500;
ellipseAreaUP = 25000;
pupilGammaCorrection = 0.85;
maskBox = [20 30];
nOtsu = 3;

% Glint settings
glintPatchRadius = 45;
glintThreshold = 0.4;

% Control stage values (after the 3th before the 6th stage)
% Cut settings: 0 for buttom cut, pi/2 for right, pi for top, 3*pi/4 for
% left
candidateThetas = pi;
minRadiusProportion = 0.8;
cutErrorThreshold = 5; % 0.25 old val

%% Loop through video name stems get each video and its corresponding masks
for ii = 5:20
    
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

