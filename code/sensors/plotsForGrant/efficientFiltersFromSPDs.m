% Generate figures using the logic introduced by Dong & Atick 1995.
% 
% To code efficiently in the face of substantial temporal correlation, the
% should be transformed to "whiten" or remove the temporal dependence.
% Assuming a linear regime, this is accomplished with a de-correlating
% filter (K). Given the natural image statistics as input, this output of this
% filter is "white". If we further assume that the input contains both the
% signal and white noise (S+N), then a low-pass Wiener filter (M) is the most
% efficient in the sense that M*K(S+N) is the closest approximation to KS
% in the least-squares sense.

subjectID = 'HERO_gka1';
sessionDate = '29-03-2023';
dropBoxBaseDir = getpref('combiLEDToolbox','dropboxBaseDir');
projectName = 'combiLED';
approachName='environmentalSampling';

% Path to the data
dataDir = fullfile(dropBoxBaseDir,...
    'MELA_data',...
    projectName,...
    approachName,...
    subjectID,sessionDate);

analysisDir = fullfile(dropBoxBaseDir,...
    'MELA_analysis',...
    projectName,...
    approachName,...
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

% Define a log-spaced x
xLogSpace = logspace(log10(0.1),log10(50));

% Set up the figure
f1 = figure();
figuresize(400,200,'pt');
set(gcf,'color','w');
t = tiledlayout(2,3);
t.TileSpacing = 'tight';
t.Padding = 'none';

plotColors = {[0 0 0],[1 0 0],[0 0 1]};
wCVals = [8,8,8];

for whichDir = 1:2

    % Get the spectral power density for this post-receptoral channel
    thisSpect = spectSet{whichDir};
    p=mean(spectSet{whichDir},2,'omitmissing');

    % There is some oscillatory signal in the environmental power spectrum
    % measurements. Not sure what this is, but we omit this in the
    % illustration of the expected 1/f2 power distributions
    if whichDir == 2
        p(64:82) = nan;
        p(204:240) = nan;
    end

    % If we wish to compare our figures to Dong 1995, replace p with this
    % expression
    %{
        p = 1./x.^2;
    %}

    % Resample p to have log-spacing of the frequencies
    p = interp1(x,p,xLogSpace,'spline');

    % The corner frequency that we will consider noise
    wC = wCVals(whichDir);

    % The index of x that contains the value closest to the corner frequency
    idxC = find(abs(xLogSpace-wC)==min(abs(xLogSpace-wC)));

    % The noise (squared) present at the corner frequency
    Nsq = p(idxC);

    % Assume that the measured environmental power spectrum is the true
    % value, plus a white noise component given by Nsq
    R = p + Nsq;

    % The de-correlating filter K
    K = 1./sqrt(R);

    % The smoothing filter M that is low-pass below the corner frequency
    M = (R - Nsq)./R;

    % The predicted sensitivity function of an optimal filter
    F = K.*M;

    % Scale it to have unit maximum sensitivity
    F = F ./ max(F);

    % Show the R
    nexttile(1,[2 1])
    loglog(xLogSpace,p./max(p),'-','Color',plotColors{whichDir},'LineWidth',2)
    hold on
    ylabel('log power relative to 0.1 Hz')
    xlabel('Frequency [Hz]')
    a = gca();
    a.XTick = [1 10 50];
    xlim([1 50]);
    a.YTick = 10.^[-8 -4 0];
    a.YTickLabel = {'-8','-4','0'};
    ylim([10^-8 1]);
    box off
    title('Observed power');

    % Show the filters
    nexttile((whichDir-1)*3+2)
    loglog(xLogSpace,K./max(K),'-','Color',plotColors{whichDir},'LineWidth',2)
    hold on
    loglog(xLogSpace,M./max(M),':','Color',plotColors{whichDir},'LineWidth',2)
    ylabel('log sensitivity')
    xlabel('Frequency [Hz]')
    a = gca();
    a.XTick = [1 10 50];
    xlim([1 50]);
    a.YTick = 10.^[-2 -1 0];
    a.YTickLabel = {'-2','-1','0'};
    ylim([10^-2 1]);
    box off
    if whichDir == 1
        title('Efficient filters');
    end

    % Show the predicted tuning function
    nexttile(3,[2,1])
    semilogx(xLogSpace,F,'-','Color',plotColors{whichDir},'LineWidth',2);
    hold on
    a = gca();
    a.XTick = [1 10 50];
    xlim([1 50]);
    ylabel('sensitivity')
    xlabel('Frequency [Hz]')
    box off
    title('Predicted tuning');
    


end



    filename = [subjectID '_' sessionDate '_' 'efficientFiltersFromSPDs.pdf'];
    export_fig(f1,fullfile(analysisDir,filename),'-Painters','-transparent');

