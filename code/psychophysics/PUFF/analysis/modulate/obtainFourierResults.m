function fitResults = obtainFourierResults(results,options)

%% argument block
arguments
    results
    options.fitFreqHz = 1/60
    options.directionLabels = {'Mel','LMS','S','LF'}
    options.phaseLabels = {'OffOn','OnOff'}
    options.contrastLabels = {'Low','High'}
    options.nTrials = 4
end


for dd = 1:length(options.directionLabels)
    for cc = 1:length(options.contrastLabels)
        for ss = 1:length(results)
            % Get the vector
            vecs=-results{ss}.(options.directionLabels{dd}).(options.contrastLabels{cc}).(options.phaseLabels{1}).palpFissure;
            vecs(options.nTrials+1:options.nTrials*2,:)=results{ss}.(options.directionLabels{dd}).(options.contrastLabels{cc}).(options.phaseLabels{2}).palpFissure;
            % Get a set of boot-strapped amplitude and phase values
            [bootAmplitude, bootPhase] = fitFourier(vecs, 'fitFreqHz', options.fitFreqHz, 'returnBoots', true);
            % Obtain the mean within Cartesian space, then covert back
            [x, y] = pol2cart(bootPhase, bootAmplitude);
            mu_x = mean(x); mu_y = mean(y);
            d = sqrt((x - mu_x).^2 + (y - mu_y).^2);
            semAmp = std(d); % The standard deviation of the boot-strap values
            % is the standard error of the mean
            [mu_phase, mu_amp] = cart2pol(mu_x, mu_y);
            % Store the results
            fitResults.(options.directionLabels{dd}).(options.contrastLabels{cc}).amplitude(ss)=mu_amp;
            fitResults.(options.directionLabels{dd}).(options.contrastLabels{cc}).phase(ss)=mu_phase;
            fitResults.(options.directionLabels{dd}).(options.contrastLabels{cc}).amplitudeSEM(ss)=semAmp;
            fitResults.(options.directionLabels{dd}).(options.contrastLabels{cc}).bootAmplitude(ss,:)=bootAmplitude;
            fitResults.(options.directionLabels{dd}).(options.contrastLabels{cc}).bootPhase(ss,:)=bootPhase;
        end
    end
end

end