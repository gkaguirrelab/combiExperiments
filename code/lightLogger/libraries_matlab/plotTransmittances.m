calLocalData = getpref('combiLEDToolbox','CalDataFolder');

figure
hold on

smoothParam = 0.02;

for ii = 0:5
    calFileName = sprintf('CombiLED_shortLLG_sphere_ND%d_maxSpectrum.mat',ii);
    load(fullfile(calLocalData,calFileName),'cals');
    calSet{ii+1} = cals{end};
    transmittance(ii+1,:)= ...
        calSet{ii+1}.rawData.gammaCurveMeanMeasurements ./ ...
        calSet{1}.rawData.gammaCurveMeanMeasurements;
    wls = SToWls(calSet{1}.rawData.S);
    y = log10(transmittance(ii+1,:));
    goodIdx = isfinite(y);
    plot(wls(goodIdx),y(goodIdx),'.');
    % label
    % add a spline fit
    yFit = csaps(wls(goodIdx),y(goodIdx),smoothParam,wls(goodIdx));
    plot(wls(goodIdx),yFit,'-k','LineWidth',1)
    text(355,min(yFit),sprintf('ND%d',ii));
end

ylabel('log transmittance');
xlabel('wavelength [nm]')
