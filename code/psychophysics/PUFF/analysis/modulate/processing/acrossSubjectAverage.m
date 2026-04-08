function avgResults = acrossSubjectAverage(results, options)

arguments
    results
    options.stimFreqHz = 1/60
end


% Extract the number of subjects, and direction, contrast, and phase labels
% from the results structure
nSubs = length(results);
directionLabels = fieldnames(results{1});
contrastLabels = fieldnames(results{1}.(directionLabels{1}));
phaseLabels = fieldnames(results{1}.(directionLabels{1}).(contrastLabels{1}));
nTrials = size(results{1}.(directionLabels{1}).(contrastLabels{1}).(phaseLabels{1}).palpFissure,1);

for dd = 1:length(directionLabels)
    for cc = 1:length(contrastLabels)
        avgVecs = [];
        for ss = 1:nSubs
            vecs = [];
            vecs(1:nTrials,:)=-results{ss}.(directionLabels{dd}).(contrastLabels{cc}).(phaseLabels{1}).palpFissure;
            vecs(nTrials+1:nTrials*2,:)=results{ss}.(directionLabels{dd}).(contrastLabels{cc}).(phaseLabels{2}).palpFissure;
            avgVecs(ss,:) = mean(vecs,'omitmissing');
        end
        [bootAmplitude, bootPhase] = fitFourier(avgVecs, 'fitFreqHz', options.stimFreqHz, 'returnBoots', true);
        [x, y] = pol2cart(bootPhase, bootAmplitude);
        mu_x = mean(x); mu_y = mean(y);
        % Some phase work here to get the positive and negative phase
        % values to correspond to the positive and negative directions of
        % eye closure response
        meanPhase = wrapToPi(atan2(mu_y, mu_x));
        d = sqrt((x - mu_x).^2 + (y - mu_y).^2);
        semAmplitude = std(d); % The standard deviation of the boot-strap values
        % is the standard error of the mean
        if meanPhase >= 0
            meanAmplitude=mean(bootAmplitude);
        else
            meanAmplitude=-mean(bootAmplitude);
        end
        % Store the data
        avgResults.(directionLabels{dd}).(contrastLabels{cc}).palpFissure = mean(avgVecs,'omitmissing');
        avgResults.(directionLabels{dd}).(contrastLabels{cc}).bootAmplitude = bootAmplitude;
        avgResults.(directionLabels{dd}).(contrastLabels{cc}).bootPhase = bootPhase;
        avgResults.(directionLabels{dd}).(contrastLabels{cc}).amplitude = meanAmplitude;
        avgResults.(directionLabels{dd}).(contrastLabels{cc}).amplitudeSEM = semAmplitude;
        avgResults.(directionLabels{dd}).(contrastLabels{cc}).phase = meanPhase;
    end
end

end
