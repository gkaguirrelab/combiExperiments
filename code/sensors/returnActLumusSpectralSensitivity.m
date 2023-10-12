function [T_actLumus,channelNames] = returnActLumusSpectralSensitivity(S)

%{
    S = [380     2   201];
    T_actLumus = returnActLumusSpectralSensitivity(S);
%}

% Load ActLumus normalized sensitivity functions
actLumusDataDir = fullfile(fileparts(mfilename('fullpath')),'actLumusValidation');
actLumusChannelSPDs = fullfile(actLumusDataDir,'ActLumusNormResponse.csv');
actLumusChannelSPDs = readtable(actLumusChannelSPDs);

% Pull out the wavelengths
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
% absolute sensitivity functions. This should now be W/m2/nm
T_actLumus = actLumusChannelSPDs./weights;

% Resample the SPDs to the passed S
T_actLumus = SplineSpd(wavelengths, T_actLumus, SToWls(S));

% Transpose the T_actLumus
T_actLumus = T_actLumus';

end