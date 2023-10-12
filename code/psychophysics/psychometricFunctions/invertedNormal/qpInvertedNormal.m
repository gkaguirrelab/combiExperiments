function responseProbabilities = qpInvertedNormal(stimParams,psiParams)
% An inverted normal distribution used for flicker nulling
%
% Usage:
%     probCorrectChoice = qpInvertedNormal(stimParams,psiParams)
%
% Description:
%   Given two intervals, one of which contains a flickering stimulus, this
%   is the probability of selecting the correct interval given a stimulus
%   property r that ranges from -1 to 1. For example, given an L and M
%   cone directed modulations, and the weights wL and wM, thethe ratio is defined as:
%
%       r = (wL - wM) / (wL + wM)
%
%  The function is an inverted Gaussian
%
%  The parameters are:
%   rNull                 - Scalar. The r value at which the subject is
%                           at chance in the detection task.
%   sigma                 - The width of the Gaussian over r
%   minCorrect            - The lowest percentage correct that is observed
%                           for any difference score
%
% Inputs:
%     stimParams          - nx1 matrix. Each row contains the stimulus
%                           parameter r
%     psiParams           - nx2 matrix. Each row has the psychometric
%                           parameters: rNull, sigma
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


%% Here is the Matlab version
if (size(psiParams,2) ~= 3)
    error('Three psi parameters required');
end
if (size(psiParams,1) ~= 1)
    error('Should be a vector');
end
if (size(stimParams,2) ~= 1)
    error('One stim parameter required');
end


%% Grab params
r = stimParams(:,1);
rNull = psiParams(:,1);
sigma = psiParams(:,2);
minCorrect = psiParams(:,3);

nStim = size(stimParams,1);
responseProbabilities = zeros(nStim,2);

%% Compute
fullR = -1:0.01:1;
maxVal = max(normpdf(fullR,rNull,sigma));
k = 1./(1-minCorrect) - 2;
pdf = normpdf(r,rNull,sigma);
probCorrect = 1-(pdf/((2+k)*maxVal));
responseProbabilities(:,1) = 1-probCorrect;
responseProbabilities(:,2) = probCorrect;

end


