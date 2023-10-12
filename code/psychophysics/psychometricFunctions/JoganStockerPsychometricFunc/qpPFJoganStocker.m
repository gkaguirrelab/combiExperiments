function probPickR2 = qpPFJoganStocker(stimParams,psiParams)
% qpPFJorganStocker  The Jorgan & Stocker JoV 2014 psychometric function
%
% Usage:
%     probPickR2 = qpPFJorganStocker(stimParams,psiParams)
%
% Description:
%   The probability, derived from signal detection theory, that an observer
%   will select reference stimulus 2 over reference stimulus 1 as more
%   similar to the test stimulus given the input properties. This is based
%   upon code written by M Jogan and described in:
%
%       M Jogan & A. Stocker. A new two-alternative forced choice method
%       for the unbiased characterization of perceptual bias and
%       discriminability. JoV, March 13, 2014, vol. 14 no.3
%
%  The parameters are:
%   r1Val, r2Val            - Scalar. The difference in a stimulus value
%                             between each reference and the test
%   rSigma, tSigma          - Noise parameters for the reference and the
%                             test
%   bias                    - Scalar. Difference between perceived value 
%                             and true value of test (in units of rSigma,
%                             tSigma)
%
% Inputs:
%     stimParams          - nx2 matrix. Each row contains the stimulus
%                           parameters: ref1Val, ref2Val
%     psiParams           - nx3 matrix. Each row has the psychometric
%                           parameters: rSigma, tSigma, bias
%
% Output:
%     probPickR2          - nx2 matrix, where each row is a vector of 
%                           predicted proportions for the outcome of
%                           selecting reference 2 as closer to the test.
%                           The first column is the probability of a "no"
%                           outcome, and the second of a "yes" outcome.
%
% Optional key/value pairs
%     None


%% Here is the Matlab version
if (size(psiParams,2) ~= 3)
    error('Three psi parameters required');
end
if (size(psiParams,1) ~= 1)
    error('Should be a vector');
end
if (size(stimParams,2) ~= 2)
    error('Two stim parameters required');
end


%% Grab params
r1Val = stimParams(:,1);
r2Val = stimParams(:,2);
tVal = 0; % We code the r2Val relative to the r1Val;
rSigma = psiParams(:,1);
tSigma = psiParams(:,2);
bias = psiParams(:,3);

nStim = size(stimParams,1);
probPickR2 = zeros(nStim,2);

%% Compute
u = r1Val - r2Val; 
v = r1Val + r2Val - (2 .* tVal);

uSigma = sqrt( 2 * rSigma.^2 );
vSigma = sqrt( 2 * rSigma.^2 + 4 * tSigma.^2);

uMean = 0;
vMean = 2 .* bias;

uCdf = normcdf(u, uMean, uSigma);
vCdf = normcdf(v, vMean, vSigma);

pChooseR2 = uCdf .* vCdf + (1-uCdf) .* (1-vCdf);

probPickR2(:,1) = 1-pChooseR2; % Probability of not choosing R2
probPickR2(:,2) = pChooseR2; % Probability of choosing R2

end


