
clear

% Pick an example subject
subject = 'BLNK_1001';

% How much contrast to illustrate?
photoContrast = 0.4;

% Define the stimulus properties
directions = {'Mel','LMS','S_peripheral','LightFlux'};
directionLabels = {'LF','Mel','LMS','S'};

% Define plot properties
directionColors = {[0 0 0],[0 1 1],[1 0.75 0],[0 0 1]};
directionLineColors = {'k','c',[1 0.75 0],'b'};

% Define the data location
experimentName = 'modulate';
dropboxBaseDir = getpref('combiExperiments','dropboxBaseDir');
dataDir = fullfile(dropboxBaseDir,'BLNK_data','PuffLight',experimentName);

% Loop through the modulation directions, load the mod file, make a plot
figure('Position',[1 1 600 600]);
tiledlayout(3,2,'TileSpacing','compact');
for dd = 1:length(directions)
    filePath = fullfile(dataDir,subject,['modResult_' directions{dd} '.mat']);
    load(filePath,'modResult');

    % How much modulation contrast do we need for the desired
    % photocontrast?
    maxPhotoContrast = mean(abs(modResult.contrastReceptorsBipolar(modResult.meta.whichReceptorsToTarget)));
    modContrast = photoContrast / maxPhotoContrast;

    % Plot the difference spectrum
    nexttile
    wavelengthsNm = modResult.wavelengthsNm;
    samplingNm = unique(diff(wavelengthsNm));
    positiveModulationSPD = modResult.positiveModulationSPD;
    negativeModulationSPD = modResult.negativeModulationSPD;
    backgroundSPD = modResult.backgroundSPD;
    refSpectrum = backgroundSPD/samplingNm;
    plot(wavelengthsNm,zeros(size(refSpectrum)),'Color',[0.5 0.5 0.5],'LineWidth',2);
    hold on
    plot(wavelengthsNm,modContrast*(positiveModulationSPD/samplingNm-refSpectrum),'k','LineWidth',2);
    plot(wavelengthsNm,modContrast*(negativeModulationSPD/samplingNm-refSpectrum),'r','LineWidth',2);
    title(directions{dd},'Interpreter','none');
    xlim([350 700]);
    ylim([-0.125 0.125]);
    xlabel('Wavelength [nm]');
    box off
    ylabel('Power [W/m^2/sr/nm]');
    a = gca();
    a.TickDir = 'out';
    a.XTick = 350:50:700;
end

% Plot the absolute background spectrum and report the illuminance
load('T_xyz1931.mat','T_xyz1931','S_xyz1931');
S = WlsToS(wavelengthsNm);
T_xyz = SplineCmf(S_xyz1931,683*T_xyz1931,S);
refSpectrumLux = T_xyz(2,:)*modResult.backgroundSPD*pi;
nexttile
plot(wavelengthsNm,refSpectrum,'Color',[0.5 0.5 0.5],'LineWidth',2);
title(sprintf('Background, %2.1f log_1_0 lux',log10(refSpectrumLux)));
xlim([350 700]);
ylim([0 0.125]);
box off
xlabel('Wavelength [nm]');
ylabel('Power [W/m^2/sr/nm]');
a=gca(); a.TickDir = 'out';
a.XTick = 350:50:700;

% Plot the photoreceptor sensitivities
nexttile
receptorsToPlot = {'L_10deg','M_10deg','S_10deg','Mel'};
nReceptors = length(modResult.meta.photoreceptors);
for ii = 1:nReceptors
    if any(strcmp(modResult.meta.photoreceptors(ii).name,receptorsToPlot))
        vec = modResult.meta.T_receptors(ii,:);
        plotColor = modResult.meta.photoreceptors(ii).plotColor;
        plot(wavelengthsNm,vec,'-','Color',plotColor,'LineWidth',2);
        hold on
    end
end
title('Receptor spectra');
xlim([350 700]);
xlabel('Wavelength [nm]');
ylabel('Relative sensitivity');
box off
a=gca(); a.TickDir = 'out';
a.XTick = 350:50:700;
