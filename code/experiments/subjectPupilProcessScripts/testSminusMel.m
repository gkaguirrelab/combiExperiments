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
pathParams.Subject = 'test';
pathParams.dataDir = '/Users/aguirre/Aguirre-Brainard Lab Dropbox/Geoffrey Aguirre/MELA_data/combiLED/test/IncrementDecrementPupil/SminusMel/2024-02-20';
pathParams.analysisDir = '/Users/aguirre/Aguirre-Brainard Lab Dropbox/Geoffrey Aguirre/MELA_analysis/combiLED/test/IncrementDecrementPupil/SminusMel/2024-02-20';


%% Analysis Notes

%% Videos

videoNameStems = {};

for ii = 1:20

     videoNameStems{ii} = sprintf('trial_%02d_trial_%02d',ii,ii);
    
end

% Mask bounds, pupil Frame mask defined in the loop as it is different for
% different videos.
glintFrameMask = [344    44   133   636];
pupilFrameMask = [344   211    85   440];

% Pupil settings
pupilCircleThreshSet = 0.004;
pupilRangeSets = [30 40];
ellipseEccenLBUB = [0.2 2];
ellipseAreaLB = 0;
ellipseAreaUP = 90000;
pupilGammaCorrection = 0.35;

% Glint settings
glintPatchRadius = 45;
glintThreshold = 0.4;

% Control stage values (after the 3th before the 6th stage)
% Cut settings: 0 for buttom cut, pi/2 for right, pi for top, 3*pi/4 for
% left
candidateThetas = pi;
minRadiusProportion = 0.8;
cutErrorThreshold = 5; % 0.25 old val

vids = 1:80;
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

