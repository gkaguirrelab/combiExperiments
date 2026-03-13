function closureResults = estimateAbsoluteClosure(pModel, pSig, varargin)
% Predicts absolute eye closure for specific photoreceptor modulations
%
% Syntax:
%   results = estimateAbsoluteClosure(pModel, pSig)
%   results = estimateAbsoluteClosure(pModel, pSig, 'background', [1000, 0, 1000], contrasts, [20 20 20 20])
%
% Inputs:
%   pModel     - 1x5 vector from fitWeightModel [wConeAvg, wConeDiff, beta,
%                slope, offset]. Run fitWeightModel to obtain.
%   pSig       - 1x2 vector from lightLevel [threshold_log10, slope]. Run
%                processLightLevelVideos to obtain.
%
% Optional:
%   sigLuminance - Background lux during sigmoid fit
%   modLuminance - Background lux during modulations
%   contrasts  - contrast on L+M+S, L+M-S, Mel, LF (L+M+S+Mel);

%% Parse inputs
p = inputParser;
addRequired(p, 'pModel');
addRequired(p, 'pSig');
addParameter(p, 'sigLuminance', 1000); % Background lux during sigmoid fit
addParameter(p, 'modLuminance', 1000); % Background lux during modulations
addParameter(p, 'contrasts', [40 40 40 40]);
addParameter(p, 'amplitudes', []); % Vector: [Mel, LMS, S, LF]
parse(p, pModel, pSig, varargin{:});

% pull out params
sigLum = p.Results.sigLuminance;
modLum = p.Results.modLuminance;
contrasts = p.Results.contrasts;
amps = p.Results.amplitudes;

%% Unpack Parameters
% From Weight Model
wConeAvg  = pModel(1);
wConeDiff = pModel(2);
beta      = pModel(3);
% From Sigmoid Fit
threshLog = pSig(1); % inflection point 
sigSlope  = pSig(2); % steepness

%% Define the Stimulus Arms [L+M+S, L+M-S, Mel]
bg = [modLum, 0, modLum];
c = contrasts / 100;

% Light Flux Arms (All receptors move by contrasts(4))
arms.LF_Pos = [bg(1)*(1+c(4)), 0, bg(3)*(1+c(4))];
arms.LF_Neg = [bg(1)*(1-c(4)), 0, bg(3)*(1-c(4))];
% Mel Arms (Only Mel moves by contrasts(1))
arms.Mel_Pos  = [bg(1), 0, bg(3)*(1+c(1))];
arms.Mel_Neg  = [bg(1), 0, bg(3)*(1-c(1))];
% LMS Arms (Only L+M+S moves by contrasts(2))
arms.LMS_Pos  = [bg(1)*(1+c(2)), 0, bg(3)];
arms.LMS_Neg  = [bg(1)*(1-c(2)), 0, bg(3)];
% S Arms (Only L+M-S moves by contrasts(3))
% L+M-S is the 2nd index of the 'bg' vector.
arms.S_Pos    = [bg(1), bg(1)*c(3), bg(3)];  % +S -LM
arms.S_Neg    = [bg(1), -bg(1)*c(3), bg(3)]; % -S +LM

%% Model Functions
% Calculate Neural Drive (D) using the beta combination logic
% Absolute values handle negative modulations within the power function
calcDrive = @(stim) (1.0 * stim(3))^beta + ...           % Mel weight is 1.0 (anchor)
                    (wConeAvg * stim(1))^beta + ...      % Extrinsic Average
                    (sign(wConeDiff) * (abs(wConeDiff) * stim(2))^beta); % Opponency

% Calculate the Drive at the sigmoid's physical threshold (p1)
% Sssume the sigmoid was fit using a standard luminance (Mel = LMS) looks
% like this is true from mod results pdf all are 1
driveAtSigThreshold = calcDrive([10^threshLog, 0, 10^threshLog]);

%Calculate the Drive of the Modulation Background
driveModBG = calcDrive(bg);

% Transfer Function: Maps any Drive (D) to the original sigmoid scale
% Uses the ratio of the current drive to the calibrated threshold
estimateClosure = @(D) 1 ./ (1 + exp(-sigSlope * (log10(D) - log10(driveAtSigThreshold))));

%% Calculate Results
fn = fieldnames(arms); % Get the names of the stimulus arms
proportions = zeros(length(fn), 1);

% Loop through only the valid fields in the 'arms' struct
for armIdx = 1:length(fn)
    dVal = calcDrive(arms.(fn{armIdx}));
    proportions(armIdx) = estimateClosure(dVal);
end

% Now handle the Background (which is calculated from driveBG, not the struct)
proportions(end+1) = estimateClosure(driveModBG);
armNames = [fn; {'Background'}];

% Assemble Table
closureResults = table(armNames, proportions, ...
    'VariableNames', {'StimulusArm', 'PredictedClosureProportion'});

%% Plotting Predicted Closure vs. Total Neural Drive
figure('Color', 'w', 'Name', 'integrated iPRGC signal');
hold on;

% Set up plot colors
directions = {'Mel','LMS','S','LF'}; % Matching fieldnames
directionColors = {[0 1 1],[1 0.75 0],[0 0 1],[0 0 0]};
colorMap = containers.Map(directions, directionColors);

% Draw the Sigmoid Curve for context
% Use the log10 of the Drive ratio relative to background
xRange = linspace(threshLog-1.5, threshLog+1.5, 200);
ySigmoid = 1 ./ (1 + exp(-sigSlope * (xRange - threshLog)));
plot(xRange, ySigmoid, '-k', 'LineWidth', 1.5, 'DisplayName', 'Model Sigmoid');

% Get Background coordinates for measured data
bgX = log10(driveModBG / driveAtSigThreshold * 10^threshLog);
bgY = proportions(end);




for armIdx = 1:length(fn)
    armName = fn{armIdx};
    dVal = calcDrive(arms.(armName));
    xVal = log10(dVal / driveAtSigThreshold * 10^threshLog);
    yValPred = proportions(armIdx);
    
    % colors
    matchIdx = cellfun(@(s) contains(armName, s), directions);
    curDir = directions{matchIdx};    % Plot Positive/Negative arms
    curCol = colorMap(curDir);

    % Determine Marker Shape and Polarity Logic
    isPosArm = contains(armName, 'Pos');
    isSDir = strcmp(curDir, 'S');
    
    % Logic: For S, we flip markers and amplitude signs
    if (isPosArm && ~isSDir) || (~isPosArm && isSDir)
        curMarker = 's'; % Square
        ySign = 1;
    else
        curMarker = 'o'; % Circle
        ySign = -1;
    end

    if isPosArm
        legStatus = 'on';
    else
        legStatus = 'off';
    end

    % Plot Predicted Points (Lower alpha/smaller)
        scatter(xVal, yValPred, 80, curMarker, 'filled', 'MarkerFaceColor', curCol, ...
            'MarkerEdgeColor', 'k', 'MarkerFaceAlpha', 0.4, 'HandleVisibility', 'off');

    % Plot Measured Points if they exist
    if ~isempty(amps)
        % Find which amplitude to use
        ampVal = amps(matchIdx);
        ampVal = ampVal(1); % ensure scalar
        
        % Calculate measured Y: background +/- half amplitude
        % If the model predicts this arm is higher than background, 
        % put the measured point at the 'top' of the amplitude.
        if yValPred >= bgY
            yValMeas = bgY + (ampVal / 2);
        else
            yValMeas = bgY - (ampVal / 2);
        end
        
        % plot measured points
        scatter(xVal, yValMeas, 140, curMarker, 'filled', 'MarkerFaceColor', curCol, ...
            'MarkerEdgeColor', 'k', 'LineWidth', 1.5, ...
            'DisplayName', ['Measured ' curDir], 'HandleVisibility', legStatus);

        % Draw a line connecting prediction to measurement (Residual)
        plot([xVal, xVal], [yValPred, yValMeas], '-', 'Color', [0.7 0.7 0.7], 'HandleVisibility', 'off');
    end
end

% Add a single proxy entry for "Predicted" in the legend
% invisible point to get the label in the legend
scatter(NaN, NaN, 80, 'filled', 'MarkerFaceColor', [0.5 0.5 0.5], ...
    'MarkerFaceAlpha', 0.4, 'MarkerEdgeColor', 'k', 'DisplayName', 'Model Predicted');

scatter(NaN, NaN, 80, 'o', 'filled', 'MarkerFaceColor', [0.5 0.5 0.5], ...
    'MarkerFaceAlpha', 0.2, 'MarkerEdgeColor', 'k', 'DisplayName', 'Model Predicted');

% Proxy for "Positive/Negative" labels if you want them explicit
scatter(NaN, NaN, 100, 's', 'k', 'DisplayName', 'Positive (Increment)');
scatter(NaN, NaN, 100, 'o', 'k', 'DisplayName', 'Negative (Decrement)');

% mark modulation background with dotted lines
plot([bgX, bgX], [0, bgY], ':r', 'HandleVisibility', 'off');
plot([min(xlim), bgX], [bgY, bgY], ':r', 'DisplayName', 'Modulation Background');

% Formatting
grid on;
xlabel('log_{10} Integrated iPRGC');
ylabel('Proportion Closed');
title('Absolute Closure Prediction and Measured by Photoreceptor Integration');
legend('Location', 'northeastoutside', 'FontSize', 8, 'Interpreter', 'none');
set(gca, 'TickDir', 'out', 'FontSize', 11);

% Display beta, wConeAvg, wConeDiff
annotation('textbox', [0.15, 0.75, 0.3, 0.1], 'String', ...
    sprintf('Beta: %.2f\nCone Avg Wt: %.2f\nCone Diff Wt: %.2f', beta, wConeAvg, wConeDiff), ...
    'FitBoxToText', 'on', 'BackgroundColor', 'w');

end