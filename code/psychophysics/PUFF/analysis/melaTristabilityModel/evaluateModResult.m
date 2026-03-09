clear

subjectID = 'BLNK_1001';
directions = {'LightFlux','Mel','LMS','S_peripheral','LminusM_MelSilent_peripheral'};
dirLabels = {'LF','Mel','LMS','S','L-M'};
photoContrast = [0.4,0.4,0.4,0.4,0.1];

% Get the dropbox path
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');

% Prepare a figure
figure('Color', 'w');
tiledlayout(1,length(directions),'TileSpacing','tight');

for dd = 1:length(directions)

    % Load this modResult
    filename = ['modResult_' directions{dd} '.mat'];
    filepath = fullfile(dropBoxBaseDir,'BLNK_data','PuffLight','modulate',subjectID);
    load(fullfile(filepath,filename),'modResult');

    % Extract S, and the background spectrum
    S = modResult.meta.cal.rawData.S;

    % If this is the first direction, obtain the lens transmittance for
    % this observer
    if dd == 1
        % Get the lens transmittance for this observer
        observerAgeInYears = modResult.meta.photoreceptors(1).observerAgeInYears;
        pupilDiameterMm = modResult.meta.photoreceptors(1).pupilDiameterMm;
        lensTransmitt = LensTransmittance(S,...
            'Human','StockmanSharpe',...
            observerAgeInYears,pupilDiameterMm)';
    end

    % Load the background spd; we don't correct for lens transmittance
    % just yet, as we need this original spd to derive the positive and
    % negative spds
    backspd = modResult.backgroundSPD;

    % If this is the first direction, calculate the
    % initial state after adapting to the background spd
    if dd == 1
        irradianceSPD = convertToMolarSpd(convertToPhotonSpd(backspd.*lensTransmitt,S,"pupilRadiusMm",pupilDiameterMm/2));
        fractions = melaStateModel(irradianceSPD,S, [1 0 0]);
        initialState = fractions(end,:);
    end

    % Calculate the modulation contrast needed to achieve the called-for
    % photoreceptor contrast
    maxPhotoContrast = mean(abs(modResult.contrastReceptorsBipolar(modResult.meta.whichReceptorsToTarget)));
    modContrast = photoContrast(dd) / maxPhotoContrast;

    % Produce the positive and negative spds
    posspd = backspd + modContrast * (modResult.positiveModulationSPD - backspd);
    negspd = backspd + modContrast * (modResult.negativeModulationSPD - backspd);

    % Adjust for lens transmittance
    posspd = posspd.*lensTransmitt;
    negspd = negspd.*lensTransmitt;

    % Move to the next tile
    nexttile;
    hold on;

    % Get the state plot for the positive, then negative modulations.
    irradianceSPD = convertToMolarSpd(convertToPhotonSpd(posspd,S,"pupilRadiusMm",pupilDiameterMm/2));
    [fractions, t] = melaStateModel(irradianceSPD, S, initialState);
    plot(t, fractions(:,1), 'k', 'LineWidth', 2);
    plot(t, fractions(:,2), 'b', 'LineWidth', 2);
    plot(t, fractions(:,3), 'r', 'LineWidth', 2);
    drawnow

    irradianceSPD = convertToMolarSpd(convertToPhotonSpd(negspd,S,"pupilRadiusMm",pupilDiameterMm/2));
    [fractions, t] = melaStateModel(irradianceSPD, S, initialState);
    plot(t, fractions(:,1), ':k', 'LineWidth', 2);
    plot(t, fractions(:,2), ':b', 'LineWidth', 2);
    plot(t, fractions(:,3), ':r', 'LineWidth', 2);
    drawnow

    xlabel('time [secs]'); ylabel('Pigment Fraction');
    if dd == 1
        legend('R (Melanopsin)', 'M (Metamelanopsin)', 'E (Extramelanopsin)');
    end
    title(dirLabels{dd},'Interpreter','none');
    ylim([0 1]);

end