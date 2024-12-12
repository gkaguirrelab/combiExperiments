function responseProbabilities = qpCumulativeNormalLapse(stimParams,psiParams)
% A cumulative normal typically used for a discrimination threshold
%
% Usage:
%     probCorrectChoice = qpCumulativeNormalLapse(stimParams,psiParams)
%
% Description:
%   Given a reference and a test interval which differ in intensity, this
%   function returns the probability that the test interval will be
%   selected as more intense. If the intensity of the reference interval is
%   given by x, the relative intensity of the test interval is given by
%   stimParam r in units of dBs.
%
%  The parameters are:
%   sigma                 - The width of the Gaussian over r
%
% Inputs:
%     stimParams          - nx1 matrix. Each row contains the stimulus
%                           parameter r
%     psiParams           - nx3 matrix. Each row has the psychometric
%                           parameters: [mu, sigma, lambda]
%
% Output:
%     responseProbabilities - nx2 matrix, where each row is a vector of 
%                           predicted proportions for the outcome of
%                           correctly selecting the stimulus interval.
%                           The first column is the probability of an 
%                           incorrect choice, and the second correct.
%     psiParamLabels      - Cell array of char vectors containing the names
%                           of the parameters
%
% Optional key/value pairs
%     None


%% Double check the inputs
if (size(psiParams,2) ~= 3)
    error('Three psi parameters required');
end
if (size(psiParams,1) ~= 1)
    error('Should be a vector');
end
if (size(stimParams,2) ~= 1)
    error('One stim parameter required');
end


%% Set up variables
r = stimParams(:,1);
mu = psiParams(:,1);
sigma = psiParams(:,2);
lambda = psiParams(:,3);
nStim = size(stimParams,1);
responseProbabilities = zeros(nStim,2);

%% Compute
probChooseTest = normcdf(r,mu,sigma)*(1-lambda*2)+lambda;
responseProbabilities(:,1) = 1-probChooseTest;
responseProbabilities(:,2) = probChooseTest;


end


