function stimOK = qpFilterJoganStockerStimDomain(stimParams)
% qpPFJorganStocker  The Jorgan & Stocker JoV 2014 psychometric function
%
% Usage:
%     probPickR2 = qpPFJorganStocker(stimParams,psiParams)
%
% Description:
%   The probability, derived from signal detection theory, that an observer
%   will select reference stimulus 2 over reference stimulus 1 as more
%   similar to the test sstimulus given the input properties. This is based
%   upon code written by M Jogan and described in:
%
%       M Jogan & A. Stocker. A new two-alternative forced choice method
%       for the unbiased characterization of perceptual bias and
%       discriminability. JoV, March 13, 2014, vol. 14 no.3
%
%  The parameters are:
%   r1Val, r2Val            - Scalar. The value of a stimulus parameter 
%                             that varies between the reference stimuli
%   tVal                    - Scalar. The value of a stimulus parameter for
%                             the test
%   rSigma, tSigma          - Noise parameters for the reference and the
%                             test
%   bias                    - Scalar. Difference between perceived value 
%                             and true value of test (in units of rVal,
%                             tVal)
%
% Inputs:
%     stimParams          - nx3 matrix. Each row contains the stimulus
%                           parameters: ref1Val, ref2Val, testVal
%     psiParams           - nx3 matrix. Each row has the psychometric
%                           parameters: rSigma, tSigma, tVal
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


%% Grab params
r1Val = stimParams(1);
r2Val = stimParams(2);

if r2Val>=r1Val
    stimOK = true;
else
    stimOK = false;
end

end


