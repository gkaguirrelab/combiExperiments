% Assuming the background we are using in the blink/squint rig, explore the
% relationship between the melanopsin states and the relative intensity of
% the background light.
%

clear

subjectID = 'BLNK_1001';
filename = 'modResult_LightFlux.mat';
dropBoxBaseDir = getpref('combiExperiments','dropboxBaseDir');
filepath = fullfile(dropBoxBaseDir,'BLNK_data','PuffLight','modulate',subjectID);
load(fullfile(filepath,filename),'modResult');


backspd = modResult.backgroundSPD;
S = modResult.meta.cal.rawData.S;
initialState = [1 0 0];
intensityRange = -1:0.25:2;
for ii = 1:length(intensityRange)
    scaledSPD = backspd * 10^intensityRange(ii);
    irradianceSPD = convertToMolarSpd(convertToPhotonSpd(scaledSPD,S));
    [fractions, t] = melaStateModel(irradianceSPD, S, initialState,'durationMax',5*60);
    data(ii,:) = fractions(end,:);
end

figure('Color', 'w');
hold on;
plot(intensityRange, data(:,1), 'k', 'LineWidth', 2); % Melanopsin (R)
plot(intensityRange, data(:,2), 'b', 'LineWidth', 2); % Metamelanopsin (M)
plot(intensityRange, data(:,3), 'r', 'LineWidth', 2); % Extramelanopsin (E)
grid on;
xlabel('log background intensity');
ylabel('Fractional Occupancy');
legend('R (Cyan)', 'M (Meta)', 'E (Violet)');
title('Absolute light level and mel states');