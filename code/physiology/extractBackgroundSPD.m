function [combinedSPD,xFreq] = extractBackgroundSPD(subjectID,modDirection,varargin)
%
%
%{
    subjectID = 'HERO_gka1';
    modDirection = 'LightFlux';
    [combinedSPD,xFreq] = extractBackgroundSPD(subjectID,modDirection);
    plot(xFreq(2:end),combinedSPD(2:end),'-r')
    a=gca();
    a.YScale='log';
    xlim([0 100]);
%}


% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('dropBoxBaseDir',getpref('combiLEDToolbox','dropboxBaseDir'),@ischar);
p.addParameter('projectName','combiLED',@ischar);
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
Fs = 2000;
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

combinedSPD = [];

for ff = 1:length(stimFreqSetHz)

    % Get the signal matrix for the zero contrast condition
    signalMat = cat(1,contrastCarryOverRaw{ff}{:,stimContrastSet==0});

    % Get the mean spd
    amp = [];
    for ii=1:size(signalMat,1)
        [xFreq,amp(ii,:)]=simpleFFT(signalMat(ii,:),Fs);
    end
    % Square to convert from amplitude to power
    meanSPD = (mean(amp)/length(xFreq)).^2;

    % remove the 60 Hz noise
    for ii=1:15
        idx = abs(xFreq-60*ii)<1.5;
        meanSPD(idx)=nan;
    end

    if ff == 1
        combinedSPD = meanSPD./length(stimFreqSetHz);
    else
        combinedSPD = combinedSPD + meanSPD./length(stimFreqSetHz);
    end

end


end
