function fitResults = obtainFourierResults(results,options)

%% argument block
arguments
    results
    options.fitFreqHz = 1/60
end

% Load the meanStimPhaseRightEyeRad. This is the phase of the stimulus in
% the recording. We adjust the phase of the response to be relative to this
% value.
meanStimPhaseRightEyeRad = processVideoLags();

% Extract the number of subjects, and direction, contrast, and phase labels
% from the results structure
directionLabels = fieldnames(results{1});
contrastLabels = fieldnames(results{1}.(directionLabels{1}));
phaseLabels = fieldnames(results{1}.(directionLabels{1}).(contrastLabels{1}));
nTrials = size(results{1}.(directionLabels{1}).(contrastLabels{1}).(phaseLabels{1}).palpFissure,1);

for dd = 1:length(directionLabels)
    for cc = 1:length(contrastLabels)
        for ss = 1:length(results)
            % Get the vector
            vecs=-results{ss}.(directionLabels{dd}).(contrastLabels{cc}).(phaseLabels{1}).palpFissure;
            vecs(nTrials+1:nTrials*2,:)=results{ss}.(directionLabels{dd}).(contrastLabels{cc}).(phaseLabels{2}).palpFissure;
            % Get a set of boot-strapped amplitude and phase values
            [bootAmplitude, bootPhase] = fitFourier(vecs, 'fitFreqHz', options.fitFreqHz, 'returnBoots', true);
            % Adjust for mean stimulus timing
            bootPhase = bootPhase - meanStimPhaseRightEyeRad;
            % Obtain the mean within Cartesian space, then covert back
            [x, y] = pol2cart(bootPhase, bootAmplitude);
            mu_x = mean(x); mu_y = mean(y);
            d = sqrt((x - mu_x).^2 + (y - mu_y).^2);
            semAmp = std(d); % The standard deviation of the boot-strap values
            % is the standard error of the mean
            [mu_phase, mu_amp] = cart2pol(mu_x, mu_y);
            % Store the results
            fitResults.(directionLabels{dd}).(contrastLabels{cc}).amplitude(ss)=mu_amp;
            fitResults.(directionLabels{dd}).(contrastLabels{cc}).phase(ss)=mu_phase;
            fitResults.(directionLabels{dd}).(contrastLabels{cc}).amplitudeSEM(ss)=semAmp;
            fitResults.(directionLabels{dd}).(contrastLabels{cc}).bootAmplitude(ss,:)=bootAmplitude;
            fitResults.(directionLabels{dd}).(contrastLabels{cc}).bootPhase(ss,:)=bootPhase;
        end
    end
end

end