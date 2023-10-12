function analyzeDetectThresholdExperiment(subjectID,modDirection,varargin)
% Code to analyze and plot results from a completed psychometric experiment
%
% Examples:
%{
    subjectID = 'HERO_gka1';
    modDirection = 'LightFlux';
    modDirection = 'LminusM_wide';
    analyzeDetectThresholdExperiment(subjectID,modDirection)
%}

% Parse the parameters
p = inputParser; p.KeepUnmatched = false;
p.addParameter('dropBoxBaseDir',getpref('combiLEDToolbox','dropboxBaseDir'),@ischar);
p.addParameter('projectName','combiLED',@ischar);
p.addParameter('leftYmax',1000,@isnumeric);
p.addParameter('showLogContrast',false,@islogical);
p.addParameter('showDeviceContrast',false,@islogical);
p.addParameter('showFit',true,@islogical);
p.addParameter('confInterval',0.68,@isnumeric);
p.addParameter('updateFigures',false,@islogical);

p.parse(varargin{:})

% Set our experimentName
experimentName = 'CDT';

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
    nBoots = 200; confInterval = p.Results.confInterval;
    [~,fitParams,fitParamsCI] = psychObj.reportParams(...
        'nBoots',nBoots,'confInterval',confInterval);
    results(ii).freqHz = psychObj.testFreqHz;
    results(ii).logContrastThresh = fitParams(1);
    results(ii).logContrastThreshLow = fitParamsCI(1,1);
    results(ii).logContrastThreshHigh = fitParamsCI(2,1);
end

% Create a plot of the results

% Sort the results by order of frequency
[~,sortIdx] = sort([results.freqHz]);
results = results(sortIdx);
% Get the contrast on the targeted receptors
contrastVec = modResult.contrastReceptorsBipolar(modResult.meta.whichReceptorsToTarget);
desiredContrast = ones(size(contrastVec));
if contains(modDirection,'LminusM')
    desiredContrast = [-1 1 -1 1]';
end
if any(desiredContrast==-1)
    modContrast = abs(mean(contrastVec(sign(desiredContrast)==1)-contrastVec(sign(desiredContrast)==-1)));
else
    modContrast = mean(contrastVec);
end

% Make a plot of the temporal contrast sensitivity function
figHandle = figure();
figuresize(200, 200,'pt');

% Set some properties of the plot based upon the modulation direction, with
% the expectation that the chromatic directions will be low-pass, and the
% light flux direction will be more band-pass
y=1./(modContrast*10.^[results.logContrastThresh]);
switch modDirection
    case 'LightFlux'
        p0 = [max(y),2,2,1];
        plotColor = 'k';
    case 'LminusM_wide'
        p0 = [max(y),9,1,2];
        plotColor = 'r';
    case 'S_LMSNull'
        p0 = [max(y),4,2,1];
        plotColor = 'b';
    otherwise
        p0 = [max(y),2,2,1];
        plotColor = 'g';
end

% Setup to plot vs. post-receptoral direction contrast
hold on
if p.Results.showDeviceContrast
    yyaxis left
end

x=[results.freqHz];

% Error bounds
patch(...
    [log10(x),fliplr(log10(x))],...
    [ 1./(modContrast*10.^[results.logContrastThreshLow]), fliplr(1./(modContrast*10.^[results.logContrastThreshHigh])) ],...
    plotColor,'EdgeColor','none','FaceColor',plotColor,'FaceAlpha',0.1);
hold on

% Data points
plot(log10(x),1./(modContrast*10.^[results.logContrastThresh]),'.','Color',plotColor,'MarkerSize',15,'LineWidth',1);

% Labels left
xlabel('frequency [Hz]')
if p.Results.showLogContrast
    ylabel({'Sensitivity',['log [1/contrast on ' modDirection ' ]']}, 'Interpreter', 'none');
else
    ylabel({'Sensitivity',['[1/contrast on ' modDirection ' ]']}, 'Interpreter', 'none');
end
a = gca;
a.XTick = log10([results.freqHz]);
a.XTickLabel = string([results.freqHz]);
leftYmax = p.Results.leftYmax;

ylim([1, leftYmax]);
ytickVals = a.YTick;

% Add a right side axis with the absolute device contrast
if p.Results.showDeviceContrast
    yyaxis right
    a = gca;
    a.YTick = ytickVals;
    ylim([1, leftYmax]);
    a.YTickLabel = string(round(1./(ytickVals*modContrast),4));
    ylabel('Device contrast [0 - 1]');

    % Set the x range
    xlim([-0.15 1.75]);

    % Return to the left axis
    yyaxis left
end

% Add a fit using the Watson temporal senisitivity function, weighted by
% the bootstrapped error
if p.Results.showFit
y=1./(modContrast*10.^[results.logContrastThresh]);
w=1./(1./(modContrast*10.^[results.logContrastThreshLow])- 1./(modContrast*10.^[results.logContrastThreshHigh]));
myWatson = @(p,x) p(1).*watsonTemporalModel(x, p(2:4));
myObj = @(p) sqrt(sum(w.*((myWatson(p,x)-y).^2)));
pFit=fmincon(myObj,p0,[],[],[],[],[1,0,0,0]);

% Add the fit
xFit = logspace(0,2,50);
yFit = myWatson(pFit,xFit);
plot(log10(xFit),(yFit),'-','Color',plotColor,'LineWidth',1.5)
end

if p.Results.showLogContrast
    a = gca();
    a.YScale = 'log';
end

% Create an anonymous function that expresses the fit result as
% absolute device contrast as a function of frequency in Hz
deviceContrastByFreqHz = @(x) 1./(modContrast*myWatson(p,x));

% save the figure
filename = fullfile(analysisDir,'ContrastThresholdByFreq.pdf');
saveas(figHandle,filename);

% save the key results
filename = fullfile(analysisDir,'ContrastThresholdByFreq.mat');
save(filename,'results','deviceContrastByFreqHz');

end
