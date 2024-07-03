function backgroundSettings = calcSettingsForD65(cal,plotResultsFlag)
% Returns primary settings that attempt to replicate the D65 SPD
%
% Syntax:
%   backgroundSettings = calcSettingsForD65(cal)
%
% Description:
%   Given a calibration file for a light source, this routine finds primary
%   settings that produce a source spectral power distribution that best
%   matches (in a least squares sense) the D65 illuminant reference.
%
% Inputs:
%   cal                   - Struct. A calibration structure. If a cell
%                           array is passed, then the last element of the
%                           array will be used.
%   plotResultsFlag       - Logical. If set to true, a plot of the best fit
%                           spd will be shown.
%
% Outputs:
%   backgroundSettings    - 1xn float vector. The settings values [0-1] for
%                           each of the n primaries in the light source.
%
% Examples:
%{
    calPath = fullfile(tbLocateProjectSilent('combiExperiments'),'cal','CombiLED_shortLLG_testSphere_ND0x2.mat');
    load(calPath,'cals');
    cal = cals{end};
    backgroundSettings = calcSettingsForD65(cal,true);
%}

% Handle the nargin
if nargin < 2
    plotResultsFlag = false;
end

% If the entire cal array has been passed, take the last entry, which
% should correspond to the most recent calibration of the light source
if iscell(cal)
    cal = cal{end};
end    

% Extract the description of the light source
sourceS = cal.rawData.S;
sourceP = cal.processedData.P_device;
nPrimaries = size(sourceP,2);

% Load the D65 SPD
D65SPDPath = fullfile(tbLocateProjectSilent('combiExperiments'),'data','D65_SPD.mat');
load(D65SPDPath,'D65_SPD_T');
D65S = WlsToS(D65_SPD_T.wls);
D65P = D65_SPD_T.spd;
D65P = D65P/max(D65P);

% Reformat that light source SPDs to be in the space of the D65 SPD
sourceP_resamp = [];
for ii = 1:nPrimaries
    sourceP_resamp(:,ii) = interp1(SToWls(sourceS),sourceP(:,ii),SToWls(D65S));
end

% Find those indices for which the sourceP is defined
goodIdx = ~isnan(sourceP_resamp(:,1));

% Project the D65P vector on to the source primaries
b = sourceP_resamp(goodIdx,:)\D65P(goodIdx);

% Scale the resulting beta values to be in the unit range
backgroundSettings = (b/max(b))';

if plotResultsFlag
    figure
    plot(SToWls(D65S),D65P,'*k');
    hold on;
    fitSPD = sourceP_resamp*b;
    plot(SToWls(D65S),fitSPD,'-r');
    xlabel('wavelength [nm]');
    ylabel('relative power')
    legend({'D65','best fit'});
end

end