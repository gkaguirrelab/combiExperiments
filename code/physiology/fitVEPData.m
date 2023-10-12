function fitVEPData(subjectID,modDirection,varargin)
%
%
%{
    subjectID = 'HERO_gka1';
    modDirection = 'LightFlux';
    fitVEPData(subjectID,modDirection);
%}
%{
    subjectID = 'HERO_gka1';
    modDirection = 'LminusM';
    fitVEPData(subjectID,modDirection);
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

% Load the VEP data. Obtain the mean SPD for each trial for each contrast
% level
respByFreq = cell(1,length(stimFreqSetHz));
for tt = 1:nTrials
    stimFreqHz = measurementRecord.trialData(tt).stimFreqHz;
    ff = find(stimFreqSetHz==stimFreqHz);
    stimContrastOrder = measurementRecord.trialData(tt).stimContrastOrder;
    dataMatrix = cell(1,length(stimContrastSet));
    evokedResponse = [];
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
        cc = stimContrastOrder(ss);
        if isempty(dataMatrix{cc})
            dataMatrix{cc} = signal;
        else
            signalMat = dataMatrix{cc};
            signalMat(end+1,:) = signal;
            dataMatrix{cc} = signalMat;
        end
    end

    % Obtain the average response across stimuli, and then the difference
    % between the non-zero and zero contrast stimuli
    for cc = 1:length(stimContrastSet)
        evokedResponse(cc,:) = mean(dataMatrix{cc});
    end
    if isempty(respByFreq{ff})
        respByTrial{1} = evokedResponse;
        respByFreq{ff} = respByTrial;
    else
        respByTrial = respByFreq{ff};
        respByTrial{end+1} = evokedResponse;
        respByFreq{ff} = respByTrial;
    end
end

% Save a timebase
xTime = vepDataStruct.timebase;

for ff = 1:length(stimFreqSetHz)

    % Get this data matrix.
    respByTrial = respByFreq{ff};

    % An index of the available trials for this stimulus frequency
    trialIdx = 1:length(respByTrial);

    % Loop over bootstrap resamplings
    for bb = 1:nBoots

        % Resample across the trials
        bootIdx = datasample(trialIdx,length(trialIdx));

        % Create the mean evoked SPD at each contrast for this boot
        for cc=1:nConstrasts-1
            meanEvokedResp(cc,:) = mean(cell2mat(cellfun(@(x) x(cc,:)',respByTrial(bootIdx),'UniformOutput',false)),2);
        end

        bootData{bb} = meanEvokedResp;
    end

    % Get the mean and SEM of the evoked response
    meanEvokedResp = mean(cat(3,bootData{:}),3);
    semEvokedResp = std(cat(3,bootData{:}),0,3);
    meanRespByFreq{ff} = meanEvokedResp;
    semRespByFreq{ff} = semEvokedResp;

end

ff=2;
response = meanRespByFreq{ff}(5,:);
mySimResponse = @(p) returnSimResponse(p,stimFreqSetHz(ff),response,xTime);
myObj = @(p) -corr(response',mySimResponse(p)');

x0 = [0.5,3,32.8];
lb = [0,0,16];
ub = [1,6,64];

p = bads(myObj,x0,lb,ub);

% plot
figure
simResponse = mySimResponse(p);
plot(xTime,response,'.','Color',[0.5 0.5 0.5])
hold on
plot(xTime,simResponse,'-r','LineWidth',2)

foo=1;

end

%% Local functions

function simResponse = returnSimResponse(p,stimFreqHz,response,xTime)

% Set the params
stimAmplitude = p(1)*100;
params = [32,3,50,7,-2,37.8125,50];
params(2) = p(2);
params(6) = p(3);


% Obtain the response
[temporalSupportSecs,temporalResponseStim] = modelSsvepEvokedResponse(params,stimFreqHz,stimAmplitude);
% Resample the response to xTime
simResponse = interp1(temporalSupportSecs,temporalResponseStim,xTime);
simResponse = simResponse-mean(simResponse);
% Find the circular shift val that maximizes the correlation of the
% response and simResponse
[r,lags] = xcorr(response,simResponse,'normalized');
[~,shiftIdx] = max(r);
simResponse = circshift(simResponse,lags(shiftIdx));
% scale the response to fit
b = simResponse'\response';
simResponse = simResponse*b;

end

