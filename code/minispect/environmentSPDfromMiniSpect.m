function [spd,modelWeights] = environmentSPDfromMiniSpect( detectorWeights )
% SPD from natural and artificial light sources to fit minispect weights
%
% Syntax:
%   [spd,modelWeights] = environmentSPDfromMiniSpect( detectorWeights )
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
	foo = 1;
    bar = myFunc(foo);
	fprintf('Bar = %d \n',bar);   
%}

% Load the minispect SPDs
miniSpectSPDPath = fullfile(tbLocateProjectSilent('combiExperiments'),'data','ASM7341_spectralSensitivity.mat');
load(miniSpectSPDPath,'T');
minispectS = WlsToS(T.wl);
minispectP = T{:,2:end};

% Load the set of light sources
enviroSPDPath = fullfile(tbLocateProjectSilent('combiExperiments'),'data','CIEDaylightComponents.mat');
load(enviroSPDPath,'CIEDaylightComponents_T');
enviroS = WlsToS(CIEDaylightComponents_T.wls);
enviroP = CIEDaylightComponents_T{:,2:end};

% Reformat the minispect SPDs to be in the space of the light sources
minispectP_resamp = [];
for ii = 1:nPrimaries
    minispectP_resamp(:,ii) = interp1(SToWls(sourceS),sourceP(:,ii),SToWls(D65S));
end