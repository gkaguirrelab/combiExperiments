% The ActLumus measures light using 10 separate channels, each with a
% different spectral sensitivity function.

actLumusDataDir = fileparts(mfilename('fullpath'));

% Load ActLumus normalized sensitivity functions
actLumusChannelSPDs = fullfile(actLumusDataDir,'ActLumusNormResponse.csv');
actLumusChannelSPDs = readtable(actLumusChannelSPDs);

% Pul out the wavelengths
wavelengths = actLumusChannelSPDs.wl;

% Separate wavelengths from the sensitivity table and convert to array. We
% drop the last, infra-red column as we have no reported weight for this
% channel, and no measurement in this range supplied by our
% spectroradiometer
actLumusChannelSPDs = table2array(actLumusChannelSPDs);
actLumusChannelSPDs = actLumusChannelSPDs(:,2:end-1);

% Weights of the channels provided by Luis from ActLumus. To convert
% ActLumus counts to W/m2, do weight/count.
channelNames = {'F1','F2','F3','F4','F5','F6','F7','F8','CLEAR'};
weights = [13.84012939453125, 7.627602905273427, 6.596852600097645, ...
           4.888952270507797, 3.986254394531233, 3.1087111816406057, ...
           3.2235953979492002, 2.585781188964824, 5.710446166992174]; 

% Scale the normalized sensitivity functions by these weights to provide
% absolute sensitivity functions
actLumusChannelSPDs = actLumusChannelSPDs./weights;

% These are the ActLumus counts reported for each channel when the device
% was directed towards the integrating sphere. These values can be found in
% the file "LabSphereActLumus.xlsx".
actLumusCountsPerChannel = ...
    [0.0028, 0.0033, 0.0047, 0.0076, 0.0134, 0.0209, 0.037, 0.0619, 0.08];

% We measured the light in an integrating sphere with the PR670. The
% resulting SPD was then resampled to match the range and intervals of the
% ActLumus. This measurement should be in W / m2 / sr / 2nm. We divide by 2
% to set the units to nm
pr670MeasuredSPD = fullfile(actLumusDataDir,'sphereSpectrum.mat');
pr670MeasuredSPD = load(pr670MeasuredSPD);
pr670MeasuredSPD = pr670MeasuredSPD.spectrum / 2;

% Multiply SPD with sensitivity functions, times the steradians in a
% hemisphere (2pi)
predictedCountsPerChannel = 2*pi*pr670MeasuredSPD'*actLumusChannelSPDs;

% Make a plot
figure
plot([0.002,0.1],[0.002,0.1],'-k','LineWidth',2)
hold on
shift = 1.25;
for ii = 1:length(predictedCountsPerChannel)
    plot(predictedCountsPerChannel(ii),actLumusCountsPerChannel(ii),'.','MarkerSize',35);
    text(predictedCountsPerChannel(ii)/shift,actLumusCountsPerChannel(ii)*shift,num2str(ii),"FontSize",16);   
end
a = gca();
a.XScale='log'; a.YScale='log';
a.XTickLabel = {'0.001','0.01','0.1'};
a.YTickLabel = {'0.001','0.01','0.1'};
xlim([0.001,0.25]);
ylim([0.001,0.25]);
a.FontSize = 14;
xlabel('Predicted radiance [W/m^2]','FontSize',14)
ylabel('ActLumus observed [W/m^2]','FontSize',14)
axis square 

% We can calculate the melanopic lux that corresponds to the sphere
% spectrum, and compare this to the value reported by the ActLumus
% software.
actLumusMelLux = 29.24;

% Conver the sphere SPD to irradiance in 2mm sampling from 380:780 in units
% of W per m2
irradiance_Wperm2 = (interp1(wavelengths,pr670MeasuredSPD,380:2:780)*pi);

