function [estimatedSPD,sourceWeights,fVal] = environmentSPDfromMiniSpect( detectorWeights )
% SPD from natural and artificial light sources to fit minispect weights
%
% Syntax:
%   [estimatedSPD,sourceWeights,fVal] = environmentSPDfromMiniSpect( detectorWeights )
%
% Description:
%   We wish to reconstruct the environmental spectral power distribution
%   from the weights on a set of narrow-band channels from the minispect.
%   To constrain this inverse mapping, we implememnt a forward model of the
%   environmental SPDs that might be created from linear combinations of
%   daylight and artificial light sources. We use a non-linear optimization
%   to find the light source combinations that yields an SPD predicted to
%   produce a set of minispect weights that best matches the observed
%   values.
%
% Inputs:
%   none
%   foo                   - Scalar. Foo foo foo foo foo foo foo foo foo foo
%                           foo foo foo foo foo foo foo foo foo foo foo foo
%                           foo foo foo
%
% Optional key/value pairs:
%   none
%  'bar'                  - Scalar. Bar bar bar bar bar bar bar bar bar bar
%                           bar bar bar bar bar bar bar bar bar bar bar bar
%                           bar bar bar bar bar bar
%
% Outputs:
%   none
%   baz                   - Cell. Baz baz baz baz baz baz baz baz baz baz
%                           baz baz baz baz baz baz baz baz baz baz baz baz
%                           baz baz baz
%
% Examples:
%{
	detectorWeights = [307, 466, 1024, 1401, 1464, 1259, 1570, 444, 3740, 228];
    [estimatedSPD,sourceWeights,fVal] = environmentSPDfromMiniSpect(detectorWeights);
%}

% Load the detector SPDs
miniSpectSPDPath = fullfile(tbLocateProjectSilent('combiExperiments'),'data','ASM7341_spectralSensitivity.mat');
load(miniSpectSPDPath,'T');
detectorS = WlsToS(T.wl);
detectorP = T{:,2:end};
nChannels = size(detectorP,2);

% Check that the length of the detectorWeights vec matches nChannels
assert(nChannels == length(detectorWeights));

% Load the set of light sources
enviroSPDPath = fullfile(tbLocateProjectSilent('combiExperiments'),'data','CIEDaylightComponents.mat');
load(enviroSPDPath,'CIEDaylightComponents_T');
enviroS = WlsToS(CIEDaylightComponents_T.wls);
enviroP = CIEDaylightComponents_T{:,2:end};

% Reformat the minispect SPDs to be in the space of the light sources
detectorP_resamp = [];
for ii = 1:nChannels
    detectorP_resamp(:,ii) = interp1(SToWls(detectorS),detectorP(:,ii),SToWls(enviroS));
end

% Create a forward model of the minispect weights based upon a combination
% of light sources
mySPD = @(x) enviroP*x';
myDetectorWeights = @(x) mySPD(x)'*detectorP_resamp;
myObj = @(x) norm(myDetectorWeights(x)-detectorWeights);

% Set the fmincon options
options = optimset('fmincon');
options.Display = 'off';

% Set the bounds. For the daylight components, it is possible to have
% negative loadings on the 2nd and 3rd component. Otherwise, all components
% are bound by zero.
lb = [0 -Inf -Inf];
ub = [Inf Inf Inf];

% Find the light source parameters that best fit the observed detector
% weights
[sourceWeights,fVal] = fmincon(myObj,[1 1 1],[],[],[],[],lb,ub,[],options);
estimatedSPD = mySPD(sourceWeights);

end
