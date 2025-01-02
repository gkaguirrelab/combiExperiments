function [sourceSPD,detectorSPD,modelS,sourceWeights,fVal] = environmentSPDfromMiniSpect( detectorWeights, options )
% SPD from natural and artificial light sources to fit minispect weights
%
% Syntax:
%   [estimatedSPD,enviroS,sourceWeights,fVal] = environmentSPDfromMiniSpect( detectorWeights )
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
    % This set of detector weights corresponds to a uniform source spectrum
	detectorWeights = [ 790   1120   1450   1900   2030   2250   1560   1900   6480    370];
    [sourceSPD,detectorSPD,modelS,sourceWeights,fVal] = environmentSPDfromMiniSpect(detectorWeights,'modelSet','polynomial');  
%}

arguments
    detectorWeights (1,10) {isvector}
    options.modelSet (1,:) char {mustBeMember(options.modelSet,{'CombiLED','polynomial','environment'})} = 'CombiLED'
    options.cal (1,:) struct = [];
end

% Load the detector SPDs
miniSpectSPDPath = fullfile(tbLocateProjectSilent('combiExperiments'),'data','ASM7341_spectralSensitivity.mat');
load(miniSpectSPDPath,'T');
detectorS = WlsToS(T.wl);
detectorP = T{:,2:end};
nDetectorChannels = size(detectorP,2);

% Check that the length of the detectorWeights vec matches nChannels
assert(nDetectorChannels == length(detectorWeights));

% Load the set of light sources
switch options.modelSet
    case 'environment'
        enviroSPDPath = fullfile(tbLocateProjectSilent('combiExperiments'),'data','CIEDaylightComponents.mat');
        load(enviroSPDPath,'CIEDaylightComponents_T');
        modelS = WlsToS(CIEDaylightComponents_T.wls);
        modelP = CIEDaylightComponents_T{:,2:end};
        % Set the bounds. For the daylight components, it is possible to have
        % negative loadings on the 2nd and 3rd component. Otherwise, all components
        % are bound by zero.
        lb = [0 -Inf -Inf];
        ub = [Inf Inf Inf];
        x0 = [1 1 1];
    case 'polynomial'
        degree = 10;
        modelS = detectorS;
        shapefcn = polyBasis('chebyshev',degree);
        modelP = zeros(modelS(3),degree+1);
        for ii = 0:modelS(3)-1
            idx = (ii-modelS(3)/2)/(modelS(3)/2);
            modelP(ii+1,:) = [1 shapefcn(idx)];            
        end
        lb = -inf(1,degree+1);
        ub = inf(1,degree+1);
        x0 = zeros(1,degree+1);
    case 'CombiLED'
        modelS = options.cal.rawData.S;
        modelP = options.cal.processedData.P_device;
        lb = [0 0 0 0 0 0 0 0];
        ub = [Inf Inf Inf Inf Inf Inf Inf Inf];
        x0 = [1 1 1 1 1 1 1 1];
end

% Reformat the minispect SPDs to be in the space of the light sources
detectorP_resamp = [];
for ii = 1:nDetectorChannels
    detectorP_resamp(:,ii) = interp1(SToWls(detectorS),detectorP(:,ii),SToWls(modelS));
end

% Create a forward model of the minispect weights based upon a combination
% of light sources
mySPD = @(x) modelP*x';
myDetectorWeights = @(x) mySPD(x)'*detectorP_resamp;
myObj = @(x) norm(myDetectorWeights(x)-detectorWeights);

% Set the fmincon options
options = optimset('fmincon');
options.Display = 'off';

% Find the light source parameters that best fit the observed detector
% weights
[sourceWeights,fVal] = fmincon(myObj,x0,[],[],[],[],lb,ub,[],options);
sourceSPD = mySPD(sourceWeights);
detectorSPD = (myDetectorWeights(sourceWeights)*detectorP_resamp')';

end
