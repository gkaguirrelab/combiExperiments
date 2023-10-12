function analyzeVEPTCSFExperiment(subjectID,modDirection,varargin)
%
%
%{
    subjectID = 'HERO_gka1';
    modDirection = 'LightFlux';
    analyzeVEPTCSFExperiment(subjectID,modDirection);
%}
%{
    subjectID = 'HERO_gka1';
    modDirection = 'LminusM_wide';
    analyzeVEPTCSFExperiment(subjectID,modDirection);
%}


% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('dropBoxBaseDir',getpref('combiLEDToolbox','dropboxBaseDir'),@ischar);
p.addParameter('projectName','combiLED',@ischar);
p.addParameter('detailedPlots',true,@islogical);
p.addParameter('savePlots',true,@islogical);
p.addParameter('nBoots',10,@isnumeric);
p.addParameter('nHarmonics',2,@isnumeric);
p.addParameter('includeSubharmonic',true,@islogical);
p.parse(varargin{:})

% Set our experimentName
experimentName = 'ssVEPTCSF';

% Define a location to load data and to save analyses
dataDir = fullfile(...
    p.Results.dropBoxBaseDir,...
    'MELA_data',...
    p.Results.projectName,...
    subjectID,modDirection,experimentName);

analysisDir = fullfile(...
    p.Results.dropBoxBaseDir,...
    'MELA_analysis',...
    p.Results.projectName,...
    subjectID,modDirection,experimentName);

% Create the analysis directory for the subject
if ~isfolder(analysisDir) && p.Results.savePlots
    mkdir(analysisDir)
end

% Load the measurementRecord
filename = fullfile(dataDir,'measurementRecord.mat');
load(filename,'measurementRecord');
nTrials = length(measurementRecord.trialData);

% Get or set the stimulus values
stimFreqSetHz = measurementRecord.stimulusProperties.stimFreqSetHz;
stimContrastSet = measurementRecord.stimulusProperties.stimContrastSet;
nFreqs = length(stimFreqSetHz);
nConstrasts = length(stimContrastSet);
nBoots = p.Results.nBoots;
nHarmonics = p.Results.nHarmonics;
Fs = 2000;
stimDurSecs = 2;
sampleShift = -150; % The offset between the ssVEP and the stimulus

% Load the VEP data, arranging the trials in matrices that reflect both the
% current and the prior contrast of each stimulus
emptyDataMatrix = cell(length(stimContrastSet),length(stimContrastSet));
contrastCarryOverRaw = cell(1,length(stimFreqSetHz));
for tt = 1:nTrials
    stimFreqHz = measurementRecord.trialData(tt).stimFreqHz;
    ff = find(stimFreqSetHz==stimFreqHz);
    if isempty(contrastCarryOverRaw{ff})
        dataMatrix = emptyDataMatrix;
    else
        dataMatrix = contrastCarryOverRaw{ff};
    end
    stimContrastOrder = measurementRecord.trialData(tt).stimContrastOrder;
    for ss = 2:length(stimContrastOrder)
        filename = sprintf('freq_%2.1f_trial_%02d_contrast_%2.1f_stim_%02d.mat',...
            stimFreqSetHz(ff),...
            tt,...
            stimContrastSet(stimContrastOrder(ss)),...
            ss );
        load(fullfile(dataDir,'rawEEGData',filename),'vepDataStruct');

        % Multiple by 100 to set as microvolt units
        signal = circshift(vepDataStruct.response*100,sampleShift);
        signal = signal-mean(signal);

        % Add to the data
        rr = stimContrastOrder(ss-1);
        cc = stimContrastOrder(ss);

        if isempty(dataMatrix{rr,cc})
            dataMatrix{rr,cc} = signal;
        else
            signalMat = dataMatrix{rr,cc};
            signalMat(end+1,:) = signal;
            dataMatrix{rr,cc} = signalMat;
        end
    end
    contrastCarryOverRaw{ff}=dataMatrix;
end

% Save a timebase
xTime = vepDataStruct.timebase;

% Create the half-cosine ramp
ramp = ones(size(xTime));
rampDur = 0.1;
ramp(1:rampDur*Fs)=(cos(pi+pi*(1:rampDur*Fs)/(rampDur*Fs))+1)/2;
ramp(length(ramp)-rampDur*Fs+1:end)=(cos(pi*(1:rampDur*Fs)/(rampDur*Fs))+1)/2;

% Now loop through the stimulus frequencies and derive:
% - The direct effect of stimulus contrast, expressed relative to the
%   zero contrast condition.
% - The carry-over effect of stimulus contrast. For this we retain the
%   response to the zero contrast state
% For each, bootstrap across trials to obtain the SEM of the effect.
carryOverMatrixAmplitude = cell(1,length(stimFreqSetHz));
carryOverMatrixSEM = cell(1,length(stimFreqSetHz));
directEffectAmplitude = cell(1,length(stimFreqSetHz));
directEffectSEM = cell(1,length(stimFreqSetHz));
modEffectAmplitude = cell(1,length(stimFreqSetHz));
modEffectSEM = cell(1,length(stimFreqSetHz));
directEffectZeroRefAmplitude = cell(1,length(stimFreqSetHz));
directEffectZeroRefSEM = cell(1,length(stimFreqSetHz));

for ff = 1:length(stimFreqSetHz)

    % Create the X regression matrix for this frequency
    X = [];

    % First create the subharmonics
    subShift = 0;
    if p.Results.includeSubharmonic
        X(:,1) = ramp.*sin(0.5*stimDurSecs*2*pi*(xTime./max(xTime))*stimFreqSetHz(ff));
        X(:,2) = ramp.*cos(0.5*stimDurSecs*2*pi*(xTime./max(xTime))*stimFreqSetHz(ff));
        subShift = 2;
    end    

    % Now the harmonics
    for hh = 1:nHarmonics
        X(:,(hh-1)*nHarmonics+1+subShift) = ramp.*sin(hh*stimDurSecs*2*pi*(xTime./max(xTime))*stimFreqSetHz(ff));
        X(:,(hh-1)*nHarmonics+2+subShift) = ramp.*cos(hh*stimDurSecs*2*pi*(xTime./max(xTime))*stimFreqSetHz(ff));
    end

    % Get this data matrix.
    dataMatrix = contrastCarryOverRaw{ff};

    % Loop over bootstrap resamplings
    ampMatrixBoot = zeros(nBoots,nConstrasts,nConstrasts);
    ampDirectBoot = zeros(nBoots,nConstrasts);
    for bb = 1:nBoots

        % Create the resample dataMatrix
        bootData = {};
        for rr=1:nConstrasts
            for cc=1:nConstrasts
                % An index of the available trials for this stimulus frequency
                trialIdx = 1:size(dataMatrix{rr,cc},1);
                % Resample across the trials
                bootIdx = datasample(trialIdx,length(trialIdx));
                bootData{rr,cc} = dataMatrix{rr,cc}(bootIdx,:);
            end
        end

        % Loop through rows and columns
        % The columns index the current stimulus contrast, the rows index
        % the prior stimulus contrast
        for rr=1:length(stimContrastSet)
            % Calculate the amplitude for each cell of the carry-over
            % matrix
            for cc=1:length(stimContrastSet)
                signalMat = bootData{rr,cc};
                meanData = mean(signalMat,1)';
                b=X\meanData;
                ampMatrix(rr,cc) = norm(b);
            end
            % Calculate the amplitude for the mean direct effect
            meanData = mean(cat(1,bootData{:,rr}))';
            b=X\meanData;
            ampDirect(rr) = norm(b);
        end
        % Store the carry-over matrix and the direct effect
        ampMatrixBoot(bb,:,:) = ampMatrix;
        ampDirectBoot(bb,:) = ampDirect;

    end

    % Assemble the various mean and SEM results across bootstraps
    carryOverMatrixAmplitude{ff} = squeeze(mean(ampMatrixBoot,1));
    carryOverMatrixSEM{ff} = squeeze(std(ampMatrixBoot,1));
    directEffectAmplitude{ff} = squeeze(mean(mean(ampMatrixBoot,2),1));
    directEffectSEM{ff} = squeeze(std(mean(ampMatrixBoot,2),1));
    modEffectAmplitude{ff} = squeeze(mean(mean(ampMatrixBoot,3),1))';
    modEffectSEM{ff} = squeeze(std(mean(ampMatrixBoot,3),1))';

    % Save a direct effect relative to zero
    ampDirectBoot = ampDirectBoot - ampDirectBoot(:,1);
    directEffectZeroRefAmplitude{ff} = mean(ampDirectBoot,1);
    directEffectZeroRefSEM{ff} = std(ampDirectBoot,1);

end


%% Plot model fit by frequency and contrast
if p.Results.detailedPlots

    % Create the figures
    f1 = figure();
    figuresize(800,800,'pt');
    t = tiledlayout(length(stimFreqSetHz),length(stimContrastSet));
    t.TileSpacing = 'compact';
    t.Padding = 'compact';

    f2 = figure();
    figuresize(800,800,'pt');
    t = tiledlayout(length(stimFreqSetHz),length(stimContrastSet));
    t.TileSpacing = 'compact';
    t.Padding = 'compact';

    for ff = 1:length(stimFreqSetHz)

        % Create the X regression matrix for this frequency
        X = [];

        % First create the subharmonics
        subShift = 0;
        if p.Results.includeSubharmonic
            X(:,1) = ramp.*sin(0.5*stimDurSecs*2*pi*(xTime./max(xTime))*stimFreqSetHz(ff));
            X(:,2) = ramp.*cos(0.5*stimDurSecs*2*pi*(xTime./max(xTime))*stimFreqSetHz(ff));
            subShift = 2;
        end

        % Now the harmonics
        for hh = 1:nHarmonics
            X(:,(hh-1)*nHarmonics+1+subShift) = ramp.*sin(hh*stimDurSecs*2*pi*(xTime./max(xTime))*stimFreqSetHz(ff));
            X(:,(hh-1)*nHarmonics+2+subShift) = ramp.*cos(hh*stimDurSecs*2*pi*(xTime./max(xTime))*stimFreqSetHz(ff));
        end

        for cc = 1:length(stimContrastSet)

            % Get this signal matrix
            signalMat = cat(1,contrastCarryOverRaw{ff}{:,cc});

            % Get the mean data
            meanData = mean(signalMat)';

            % Fourier regression fit
            b=X\meanData;
            fitY = X*b;

            % Get the mean spd
            amp = [];
            for ii=1:size(signalMat,1)
                [xFreq,amp(ii,:)]=simpleFFT(signalMat(ii,:),Fs);
            end
            meanSPD = mean(amp)/length(xFreq);

            % remove the 60 Hz noise
            for ii=1:15
                idx = abs(xFreq-60*ii)<1.5;
                meanSPD(idx)=nan;
            end

            % Plot the mean response and fit
            figure(f1);
            nexttile
            plot(xTime,meanData,'-','Color',[0.75 0.75 0.75],'LineWidth',1.25);
            hold on
            plot(xTime,fitY,'-','Color','r','LineWidth',1.25);
            ylim([-5 5]);
            if cc==1
                title(sprintf('freq %2.2f',stimFreqSetHz(ff)))
                if ff==1
                    xlabel('time [secs]')
                    ylabel('microvolts')
                end
            end

            % Plot the mean spd
            figure(f2);
            nexttile
            a=gca();
            a.XScale='log';

            % Put up a patch to indicate the stimulus freq
            for hh = 1:nHarmonics
                [~,xIdx] = min(abs(xFreq-hh*stimFreqSetHz(ff)));
                patch( ...
                    [xFreq(xIdx)*0.9,xFreq(xIdx)*0.9,xFreq(xIdx)*1.1,xFreq(xIdx)*1.1], ...
                    [0 3 3 0],'r','EdgeColor','none','FaceColor','r','FaceAlpha',0.1);
                hold on
            end
            if p.Results.includeSubharmonic
                [~,xIdx] = min(abs(xFreq-0.5*stimFreqSetHz(ff)));
                patch( ...
                    [xFreq(xIdx)*0.9,xFreq(xIdx)*0.9,xFreq(xIdx)*1.1,xFreq(xIdx)*1.1], ...
                    [0 3 3 0],'r','EdgeColor','none','FaceColor','r','FaceAlpha',0.1);
            end
            plot(xFreq(2:end),meanSPD(2:end),'-','Color',[0.25 0.25 0.25],'LineWidth',1.25);
            ylim([0 3]);
            xlim([0.5 200]);
            xlim([0 100]);
            if cc==1
                title(sprintf('freq %2.2f',stimFreqSetHz(ff)))
                if ff==1
                    xlabel('freq Hz]')
                    ylabel('log microvolts')
                end
            end
        end
    end

    if p.Results.savePlots
        filename = [subjectID '_' modDirection '_' 'ssVEP-timeFits.pdf'];
        saveas(f1,fullfile(analysisDir,filename));
        filename = [subjectID '_' modDirection '_' 'ssVEP-spdFits.pdf'];
        saveas(f2,fullfile(analysisDir,filename));
    end

end


%% Temporal sensitivity
f3=figure;
logX = log10(stimFreqSetHz);
cmap = flipud(copper(length(stimContrastSet)-1));
for cc = 1:length(stimContrastSet)-1
    % Get the amplitudes and SEMS across the frequencies
    vec = cellfun(@(x) x(cc+1),directEffectZeroRefAmplitude);
    sem = cellfun(@(x) x(cc+1),directEffectZeroRefSEM);
    patch(...
        [logX,fliplr(logX)],...
        [vec+sem,fliplr(vec-sem)],...
        cmap(cc,:),'EdgeColor','none','FaceColor',cmap(cc,:),'FaceAlpha',0.1);
    hold on
    plot(logX,vec,'.-','Color',cmap(cc,:),'MarkerSize',15,'LineWidth',1);
end
tmp = diff(logX);
limRange = [min(logX)-tmp(1), max(logX)+tmp(end)];
xlim(limRange);
plot(limRange,[0 0],':k')
a=gca();
a.XTick=logX;
a.XTickLabels = arrayfun(@(x) {num2str(x)},stimFreqSetHz);
xlabel('stimulus frequency [Hz]')
ylabel('amplitude relative to zero contrast [micro volts]')
cbh=colorbar;
cbh.Ticks = 0.1:0.2:0.9;
cbh.TickLabels = arrayfun(@(x) {num2str(x)},stimContrastSet(2:end));
cbh.Label.String = 'contrast';
colormap(cmap);

if p.Results.savePlots
    filename = [subjectID '_' modDirection '_' 'ssVEP-TTF.pdf'];
    saveas(f3,fullfile(analysisDir,filename));
end



%% Carry-over figure
f4=figure;
figuresize(325,400,'pt')

% Direct effect
subplot(5,4,[1 2 3]);
logX = log10(stimContrastSet);
logX(1) = -1.6;
xRange = [min(logX)-mean(diff(logX))/2, max(logX)+mean(diff(logX))/2];
tmpAmp = cat(2,directEffectAmplitude{:});
tmpSEM = cat(2,directEffectSEM{:});
tmpAmp = tmpAmp./max(tmpAmp);
tmpSEM = tmpSEM./max(tmpAmp);
vec = mean(tmpAmp,2)';
sem = mean(tmpSEM,2)';
plot(xRange,[vec(1) vec(1)],':k');
hold on
patch(...
    [logX,fliplr(logX)],...
    [vec+sem,fliplr(vec-sem)],...
    'k','EdgeColor','none','FaceColor','k','FaceAlpha',0.1);
plot(logX,vec,'.-','Color','k','MarkerSize',15,'LineWidth',2);
ylabel('response');
xlabel('contrast')
ylim([0 1.25]);
xlim(xRange);
a = gca();
a.XAxis.Visible = 'off';
box off

% Modulatory effect
subplot(5,4,[8 12 16]);
tmpAmp = cat(2,modEffectAmplitude{:});
tmpSEM = cat(2,modEffectSEM{:});
tmpAmp = tmpAmp./max(tmpAmp);
tmpSEM = tmpSEM./max(tmpAmp);
vec = mean(tmpAmp,2)';
vec = vec-mean(vec);
sem = mean(tmpSEM,2)';
plot([0 0],xRange,':k');
hold on
patch(...
    [vec+sem,fliplr(vec-sem)],...
    [logX,fliplr(logX)],...
    'k','EdgeColor','none','FaceColor','k','FaceAlpha',0.1);
plot(vec,logX,'.-','Color','k','MarkerSize',15,'LineWidth',2);
xlabel('modulation');
ylabel('contrast')
xlim([-0.15 +0.15]);
ylim([min(logX)-mean(diff(logX))/2, max(logX)+mean(diff(logX))/2]);
a = gca();
a.XTick = [-0.15,0,0.15];
a.YAxisLocation = "right";
a.YAxis.Visible = 'off';
box off

% Carry-over matrix
tmp = cat(3,carryOverMatrixAmplitude{:});
for ii = 1:size(tmp,3)
    tmp(:,:,ii) = tmp(:,:,ii) ./ max(tmp(:,:,ii),[],'all');
end
avgMatrix = squeeze(mean(tmp,3));
subplot(5,4,[5 6 7 9 10 11 13 14 15]);
cmap = [ linspace(0,1,255);[linspace(0,0.5,127) linspace(0.5,0,128)];[linspace(0,0.5,127) linspace(0.5,0,128)]]';
im = 2*(avgMatrix - 0.5);
im = round(im * 128 + 128);
image(im);
colormap(cmap)
axis normal
a = gca();
a.YDir = 'normal';
a.XTick = 1:length(stimContrastSet);
a.YTick = 1:length(stimContrastSet);
a.XTickLabels = arrayfun(@(x) {num2str(x)},stimContrastSet);
a.YTickLabels = arrayfun(@(x) {num2str(x)},stimContrastSet);
a.XAxis.TickLength = [0 0];
a.YAxis.TickLength = [0 0];
xlabel('current contrast');
ylabel('prior contrast');
box off

% Color map
subplot(5,4,[17 18 19]);
hCB = colorbar('south','AxisLocation','in');
hCB.Label.String = 'relative ssVEP response';
set(gca,'Visible',false)

if p.Results.savePlots
    filename = [subjectID '_' modDirection '_' 'ssVEP-carryOver.pdf'];
    saveas(f4,fullfile(analysisDir,filename));
end

end
