calLocalData = getpref('combiLEDToolbox','CalDataFolder');

figure
hold on

smoothParam = 1e-1;

for ii = 0:3
    calFileName = sprintf('CombiLED_shortLLG_sphere_ND%d_maxSpectrum.mat',ii);
    load(fullfile(calLocalData,calFileName),'cals');
    calSet{ii+1} = cals{end};
    transmittance(ii+1,:)= ...
        calSet{ii+1}.rawData.gammaCurveMeanMeasurements ./ ...
        calSet{1}.rawData.gammaCurveMeanMeasurements;
    wls = SToWls(calSet{1}.rawData.S);
    plot(wls,log10(transmittance(ii+1,:)));
    % label
    yPos = log10(transmittance(ii+1,1))*1.1;
    text(min(wls),yPos,sprintf('ND%d',ii));
    % add a spline fit
    yFit = csaps(wls,log10(transmittance(ii+1,:)),smoothParam,wls);
    plot(wls,yFit,'-k')
end

ylabel('log transmittance');
xlabel('wavelength [nm]')
