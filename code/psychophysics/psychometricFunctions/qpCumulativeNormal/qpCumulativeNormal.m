function responseProbabilities = qpCumulativeNormal(stimParams,psiParams)
% A cumulative normal typically used for a discrimination threshold
%
% Usage:
%     probCorrectChoice = qpCumulativeNormal(stimParams,psiParams)
%
% Description:
%   Given two intervals, one of which contains a more intense stimulus,
%   this is the probability of correctly selecting the more intense
%   interval given a stimulus property r that ranges from -inf to inf.
%
%  The parameters are:
%   sigma                 - The width of the Gaussian over r
%
% Inputs:
%     stimParams          - nx1 matrix. Each row contains the stimulus
%                           parameter r
%     psiParams           - nx2 matrix. Each row has the psychometric
%                           parameters: [mu, sigma]
%
% Output:
%     responseProbabilities - nx2 matrix, where each row is a vector of 
%                           predicted proportions for the outcome of
%                           correctly selecting the stimulus interval.
%                           The first column is the probability of an 
%                           incorrect choice, and the second correct.
%
% Optional key/value pairs
%     None


%% Double check the inputs
if (size(psiParams,2) ~= 2)
    error('Two psi parameters required');
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
nStim = size(stimParams,1);
responseProbabilities = zeros(nStim,2);

%% Compute
probCorrect = normcdf(r,mu,sigma);
responseProbabilities(:,1) = 1-probCorrect;
responseProbabilities(:,2) = probCorrect;

end


