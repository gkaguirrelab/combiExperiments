function [p,fVals] = fitWeightModel(fourierFitResults)
% Fits a 5-parameter non-linear photoreceptor weight model to individual subject 
% Fourier amplitude data across stimulus directions (Mel, LMS, S, LF) and contrasts.
% Model parameters estimate cone extrinsic weights relative to a fixed Melanopsin weight (wMel = 1).
%
% [p, fVals] = fitWeightModel(fourierFitResults)
%
% Fits a non-linear photoreceptor combination model to individual-subject response amplitudes.
% Phase-adjusted Fourier amplitudes are fitted across 4 isolation directions (Mel, LMS, S, LF)
% and 2 contrast levels (High, Low) using weighted L2-norm optimization (fmincon).
%
% Parameters estimated per subject in p:
%   p(1): wConeAvg  - Average absolute cone extrinsic weight (relative to wMel = 1)
%   p(2): wConeDiff - Difference in cone extrinsic weights (relative to wMel = 1)
%   p(3): beta      - Combination exponent for multi-receptor interactions
%   p(4): slope     - Sensitivity gain factor
%   p(5): offset    - Baseline response offset
% Data properties
nSubjects = length(fourierFitResults.Mel.High.amplitude);

% Stimulus properties
directions = {'Mel','LMS','S','LF'};
directionColors = {[0 1 1],[1 0.75 0],[0 0 1],[0 0 0]};
contrastLabels = {'High','Low'};
contrasts = {[40 40 40 40],[20 20 20 20]};
contrastMarkerSize = [150,75];

% Model parameters:
%   - average absolute cone extrinsic weight (relative to Mel weight)
%   - difference in cone extrinsic weights (relative to Mel weight)
%   - combination exponent (relevant for LF)
%   - slope of sensitivity function
%   - intercept of sensitivity function
x0 = [0.2,0.2,1,0.1,0];
lb = [-1,-1,1,0,0];
ub = [1,1,1,1,0];

% Define the model output
myModel = @(p) valsForSet(directions,contrasts,p);

% Prepare the model opts
opts = optimoptions('fmincon');
opts.Display = 'none';

% Prepare a figure
figure('WindowStyle', 'normal');
plot([-0.3,0.4],[-0.3,0.4],'--k');
hold on
plot([0,0],[-0.3,0],':k');
plot([-0.3,0],[0,0],':k');

% Loop through subjects
for ss = 1:nSubjects
    yVals = []; wVals = [];
    % Assemble the data matrix
    for dd = 1:length(directions)
        for cc = 1:length(contrasts)
            phase = fourierFitResults.(directions{dd}).(contrastLabels{cc}).phase(ss);
            if phase >= pi/2 && phase < 3*pi/2
                ampSign = -1;
            else
                ampSign = 1;
            end
            yVals(dd,cc) = ampSign*fourierFitResults.(directions{dd}).(contrastLabels{cc}).amplitude(ss);
            wVals(dd,cc) = 1/fourierFitResults.(directions{dd}).(contrastLabels{cc}).amplitudeSEM(ss);
        end
    end
    % normalize the wVals
    wVals = wVals ./ mean(wVals(:));

    % Define the objective function
    myObj = @(p) calcModelError(myModel(p),yVals,wVals);

    % Perform the search
    [p(ss,:),fVals(ss)] = fmincon(myObj,x0,[],[],[],[],lb,ub,[],opts);

    % Store the yVals
    data{ss}=yVals;

    % Add these data to the plot
    k = myModel(p(ss,:));
    for dd = 1:length(directions)
        for cc = 1:length(contrastLabels)
            scatter(yVals(dd,cc),k(dd,cc),contrastMarkerSize(cc),'o',...
                'MarkerFaceColor',directionColors{dd},...
                'MarkerFaceAlpha',0.5,...
                'MarkerEdgeColor','none');
        end
    end
end
axis square
box off
xlabel('Measured response');
ylabel('Modeled response');

% Convert the average difference parameters into L and S params
wLplusM = p(:,1)+p(:,2)/2;
wS = p(:,1)-p(:,2)/2;

end


% Local

function fVal = calcModelError(fitVals,yVals,wVals)

normVal = 2;
fVal = (sum(((yVals(:)-fitVals(:)).*wVals(:)).^normVal)).^(1/normVal);
end

function fitVals = valsForSet(directions,contrasts,p)

for dd = 1:length(directions)
    for cc = 1:length(contrasts)
        thisDirection = directions{dd};
        thisContrast = contrasts{cc}(dd);
        fitVals(dd,cc) = valForStimulus(thisDirection,thisContrast,p);
    end
end
end

function fitVal = valForStimulus(direction,contrast,p)

% Unpack the parameters
wMel = 1;
wConeAvg = p(1);
wConeDiff = p(2);
beta = p(3);
slope = p(4);
offset = p(5);

switch direction
    case 'LF'
        stage1 = (wMel.*contrast).^beta + ...
            sign(wConeDiff)*(abs(wConeDiff).*contrast).^beta;
    case 'Mel'
        stage1 = (wMel.*contrast).^beta;
    case 'LMS'
        stage1 = sign(wConeDiff)*(abs(wConeDiff).*contrast).^beta;
    case 'S'
        stage1 = -(wConeAvg.*contrast).^beta;
end

signStage1 = sign(stage1);
stage1 = abs(stage1).^(1/beta);
fitVal = signStage1.*log10(1+stage1)*slope+offset;

end