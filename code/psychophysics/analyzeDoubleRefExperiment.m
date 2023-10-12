function analyzeDoubleRefExperiment(subjectID,modDirection,varargin)
% Code to analyze and plot results from a completed psychometric experiment
%
% Examples:
%{
    subjectID = 'HERO_gka1';
    modDirection = 'LightFlux';
    analyzeDoubleRefExperiment(subjectID,modDirection)
%}

% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('dropBoxBaseDir',getpref('combiLEDToolbox','dropboxBaseDir'),@ischar);
p.addParameter('projectName','combiLED',@ischar);
p.addParameter('confInterval',0.68,@isnumeric);
p.addParameter('updateFigures',false,@islogical);

p.parse(varargin{:})

% Set our experimentName
experimentName = 'DoubleRef';

% Set a random seed to a reproducible state so that bootstrap results are
% consistent across re-runs of the routine
rng(1);

% Define a location to load data and save analyses
modDir = fullfile(...
    p.Results.dropBoxBaseDir,...
    'MELA_data',...,
    p.Results.projectName,...
    subjectID,modDirection);

dataDir = fullfile(modDir,experimentName);

analysisDir = fullfile(...
    p.Results.dropBoxBaseDir,...
    'MELA_analysis',...,
    p.Results.projectName,...
    subjectID,modDirection,experimentName);

% Create a directory for analysis output
if ~isfolder(analysisDir)
    mkdir(analysisDir)
end


% Load the modResult
filename = fullfile(modDir,'modResult.mat');
% The modResult may be a nulled modulation, so handle the possibility
% of the variable name being different from "modResult".
tmp = load(filename);
fieldname = fieldnames(tmp);
modResult = tmp.(fieldname{1});

% Load the measurementRecord
filename = fullfile(dataDir,'measurementRecord.mat');
load(filename,'measurementRecord');

% Identify all of the unique psych objects in the sessionRecord
fileStems = unique([measurementRecord.sessionData.fileStem]);

% Loop through the psychometric objects, plot the outcomes, and obtain
% boot-strapped estimates of the params
results = [];
for ii=1:length(fileStems)
    % Load the object
    filename = fullfile(dataDir,[fileStems{ii} '.mat']);
    load(filename,'psychObj');
    % Only update the psychometric object plots if asked
    if p.Results.updateFigures
        % Make the plot
        figHandle = psychObj.plotOutcome('off');
        % Save the plot
        filename = fullfile(dataDir,[fileStems{ii} '.pdf']);
        saveas(figHandle,filename,'pdf')
        close(figHandle)
    end
    % Obtain boot-strapped params
    nBoots = 20; confInterval = p.Results.confInterval;
    [~,fitParams,fitParamsCI] = psychObj.reportParams(...
        'nBoots',nBoots,'confInterval',confInterval);
    results(ii).refContrastDb = str2double(psychObj.testContrastLabel);
    results(ii).testContrastDb = str2double(psychObj.refContrastLabel);
    results(ii).testFreqHz = psychObj.testFreqHz;
    % The params are in the order rSigma, tSigma, bias
    results(ii).fitParams = fitParams;
    results(ii).fitParamsCI = fitParamsCI;
end

% save the key results
filename = fullfile(analysisDir,'DoubleRef2AFCDiscrim.mat');
save(filename,'results');

% Make a figure
figHandle = figure();
figuresize(600, 200,'pt');

% Plot rSigma vs. reference contrast.
subplot(1,4,1);
hold on
levelSet = unique([results.refContrastDb]);
% Create a weighted average of rSigma values at each reference
% contrast level
for ii=1:length(levelSet)
    idx = find(levelSet(ii) == [results.refContrastDb]);
    vals = reshape([results(idx).fitParams],3,length(idx));
    vals = vals(1,:);
    weights = reshape(diff([results(idx).fitParamsCI],1),3,length(idx));
    weights = weights(1,:);
    weights = 1./weights;
    weights(isinf(weights)) = max(weights(~isinf(weights)));
    val = sum(vals.*weights)./sum(weights);
    plot(levelSet(ii),val,'or')
end
xlim([2 14]);
xlabel('ref contrast [Dbs of threshold]')
ylabel('modulation contrast [0-1]')
title('ref noise sigma by contrast')

% Plot tSigma vs. reference contrast.
subplot(1,4,2);
hold on
levelSet = unique([results.testContrastDb]);
% Create a weighted average of rSigma values at each reference
% contrast level
for ii=1:length(levelSet)
    idx = find(levelSet(ii) == [results.testContrastDb]);
    vals = reshape([results(idx).fitParams],3,length(idx));
    vals = vals(2,:);
    weights = reshape(1./diff([results(idx).fitParamsCI],1),3,length(idx));
    weights = weights(2,:);
    weights(isinf(weights)) = max(weights(~isinf(weights)));
    val = sum(vals.*weights)./sum(weights);
    plot(levelSet(ii),val,'or')
end
xlim([2 14]);
xlabel('test contrast [Dbs of threshold]')
ylabel('modulation contrast [0-1]')
title('test noise sigma by contrast')

% Plot bias vs. test frequency
subplot(1,4,3);
hold on
levelSet = unique([results.testFreqHz]);
% Create a weighted average of bias values at each test freq. The bias is
% given in log units, so we have to reference this to the test frequency to
% know how much bias (in absolute Hz) is present
for ii=1:length(levelSet)
    idx = find(levelSet(ii) == [results.testFreqHz]);
    vals = reshape([results(idx).fitParams],3,length(idx));
    vals = vals(3,:);
    weights = reshape(1./diff([results(idx).fitParamsCI],1),3,length(idx));
    weights = weights(3,:);
    weights(isinf(weights)) = max(weights(~isinf(weights)));
    val = sum(vals.*weights)./sum(weights);
    plot(log10(levelSet(ii)),10.^val,'or')
end
xlim([0.5 1.5]);
xlabel('test freq [log Hz]')
ylabel('bias [Hz]')
title('test bias by freq')

% Plot sigma vs. test frequency
subplot(1,4,4);
hold on
levelSet = unique([results.testFreqHz]);
% Create a weighted average of bias values at each test freq
for ii=1:length(levelSet)
    idx = find(levelSet(ii) == [results.testFreqHz]);
    vals = reshape([results(idx).fitParams],3,length(idx));
    vals = vals(2,:);
    weights = reshape(1./diff([results(idx).fitParamsCI],1),3,length(idx));
    weights = weights(3,:);
    weights(isinf(weights)) = max(weights(~isinf(weights)));
    val = sum(vals.*weights)./sum(weights);
    plot(log10(levelSet(ii)),log10(1./(10.^val)),'or')
end
xlim([0.5 1.5]);
xlabel('test freq [log Hz]')
ylabel('sensitivity (1/noise width [Hz])')
title('test noise sigma by freq')

% save the figure
filename = fullfile(analysisDir,'DoubleRefResults.pdf');
saveas(figHandle,filename);

end
