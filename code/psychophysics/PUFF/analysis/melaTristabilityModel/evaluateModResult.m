clear

subjectID = 'BLNK_1001';
directions = {'LightFlux','Mel','LMS','S_peripheral','LminusM_MelSilent_peripheral'};
dirLabels = {'LF','Mel','LMS','S','L-M'};
photoContrast = [0.4,0.4,0.4,0.4,0.1];

% We find that attenuating the background intensity by this many log units
% places the model in the most sensitive range for changes in melanopsin
% states. A problem, however, is that this results in unreasonably slow
% kinetics. Not sure how to resolve this yet.
attenFactor = -1.75;

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
    backspd = modResult.backgroundSPD;

    % If this is the first direction, calculate the
    % initial state after adapting to the background spd
    if dd == 1
    fractions = melaStateModel(convertToMolarSpd(backspd*10^attenFactor,S), S, [1 0 0]);
    initialState = fractions(end,:);
    end

    % Calculate the modulation contrast needed to achieve the called-for
    % photoreceptor contrast
    maxPhotoContrast = mean(abs(modResult.contrastReceptorsBipolar(modResult.meta.whichReceptorsToTarget)));
    modContrast = photoContrast(dd) / maxPhotoContrast;

    % Produce the positive and negative spds
    posspd = backspd + modContrast * (modResult.positiveModulationSPD - backspd);
    negspd = backspd + modContrast * (modResult.negativeModulationSPD - backspd);

    % Move to the next tile
    nexttile;
    hold on;

    % Get the state plot for the positive, then negative modulations.
    [fractions, t] = melaStateModel(convertToMolarSpd(posspd*10^attenFactor,S), S, initialState);
    plot(t, fractions(:,1), 'k', 'LineWidth', 2);
    plot(t, fractions(:,2), 'b', 'LineWidth', 2);
    plot(t, fractions(:,3), 'r', 'LineWidth', 2);
    drawnow

    [fractions, t] = melaStateModel(convertToMolarSpd(negspd*10^attenFactor,S), S, initialState);
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