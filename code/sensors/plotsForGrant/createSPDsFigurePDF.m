function createSPDsFigurePDF(subjectID,sessionDate,varargin)

%{
subjectID = 'HERO_gka1';
sessionDate = '29-03-2023';
createSPDsFigurePDF(subjectID,sessionDate);
%}

% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('dropBoxBaseDir',getpref('combiLEDToolbox','dropboxBaseDir'),@ischar);
p.addParameter('projectName','combiLED',@ischar);
p.addParameter('approachName','environmentalSampling',@ischar);
p.addParameter('fps',112.5,@isnumeric);
p.addParameter('windowDurFrames',1200,@isnumeric);
p.addParameter('windowStepFrames',600,@isnumeric);
p.addParameter('savePlots',true,@islogical);
p.parse(varargin{:})

windowStepSecs = p.Results.windowStepFrames/p.Results.fps;

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

% Get the list of videos
videoDir = fullfile(dataDir,'videos');
videoList =dir(fullfile(videoDir,'*','*.avi'));


% Initialize a cell variable. This is kinda ugly code
for cc = 1:3; spectSet{cc} = []; end

% Load and clean the spectrograms
for vv = 1:length(videoList)
    resultFilename = fullfile(analysisDir,[videoList(vv).name '_spectrogram.mat']);

    load(resultFilename,'spectrogram','frq');

    % Throw away the zero and nyquist frequencies
    spectrogram = spectrogram(:,:,2:end-1);
    x = frq(2:end-1);

    % log-transform and smooth the spectrogram
    for cc=1:3
        % Get this post-receptoral direction
        k = squeeze(spectrogram(cc,:,:));

        % Covert from amplitude to spectral power density
        k=(k.^2)./x;

        % Smooth the spectrum (in log space)
        k = log10(k);
        s = size(k);
        k = reshape(smooth(k(:),10),s(1),s(2))';
        k = 10.^k;

        % Save the spectSet
        spectSet{cc} = [spectSet{cc},k,nan(size(k,1),4)];
    end

end

% Set up the figure
f1 = figure();
figuresize(200,200,'pt');
set(gcf,'color','w');

% The three spectrograms
xAxisVals = [0.1,1,10,50];
directions = {'LMS','L–M','S'};
plotColors = {'k','r','b'};
for cc = 1:3
    k=mean(spectSet{cc},2,'omitmissing');
    semilogx(x,log10(k),'-','Color',plotColors{cc},'LineWidth',2);
    hold on
end

vec = log10(1./(x.^2));
vec = vec-vec(1);
semilogx(x,vec,':k');
semilogx(x,vec+6,':k');

legend({'L+M','L–M','S'})
a = gca;
a.TickDir = 'out';
a.XTick = xAxisVals;
a.XTickLabel = arrayfun(@(x) {num2str(x)},xAxisVals);
ylim([-6 6])
a.YTick = [-6,-3,0,3,6];
xlim([0.1 50])
xlabel('Frequency [Hz]');
ylabel({'log Power'})
box off
axis square
title({'Temporal SPDs of','natural environment at','lowest spatial frequency'})



if p.Results.savePlots
    filename = [subjectID '_' sessionDate '_' 'environmentSPD.pdf'];
    export_fig(f1,fullfile(analysisDir,filename),'-Painters','-transparent');
end

end % Function


