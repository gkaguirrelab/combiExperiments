calLocalData = getpref('combiLEDToolbox','CalDataFolder');

figure
hold on

smoothParam = 0.02;

for ii = 0:4
    calFileName = sprintf('CombiLED_shortLLG_sphere_ND%d_maxSpectrum.mat',ii);
    load(fullfile(calLocalData,calFileName),'cals');
    calSet{ii+1} = cals{end};
    transmittance(ii+1,:)= ...
        calSet{ii+1}.rawData.gammaCurveMeanMeasurements ./ ...
        calSet{1}.rawData.gammaCurveMeanMeasurements;
    wls = SToWls(calSet{1}.rawData.S);
    y = log10(transmittance(ii+1,:));
    goodIdx = isfinite(y);
    plot(wls(goodIdx),y(goodIdx));
    % label
    yPos = y(1)-0.3;
    text(min(wls),yPos,sprintf('ND%d',ii));
    % add a spline fit
    yFit = csaps(wls(goodIdx),y(goodIdx),smoothParam,wls(goodIdx));
    plot(wls(goodIdx),yFit,'-k')
    ylim([yPos,0])
end

ylabel('log transmittance');
xlabel('wavelength [nm]')
