function modResult = returnAdjustedModResult(obj,adjustWeight)

% Extract the settings
settingsHigh = obj.modResult.settingsHigh;
settingsLow = obj.modResult.settingsLow;
settingsBackground = obj.modResult.settingsBackground;

% Scale the settings to create headroom for the adjustment
settingsHigh = (settingsHigh - settingsBackground) * (1-abs(adjustWeight)) + settingsBackground;
settingsLow = (settingsLow - settingsBackground) * (1-abs(adjustWeight)) + settingsBackground;

% Adjust the high or low settings, flipping the sign of the adjust weight
% when it is applied to low settings.
if obj.adjustHighSettings
    settingsHigh = settingsHigh + ...
        adjustWeight * (obj.adjustSettingsVec - settingsBackground);
else
    settingsLow = settingsLow - ...
        adjustWeight * (obj.adjustSettingsVec - settingsBackground);
end

% Loop through cycles of expanding and centering
for ii = 1:10

    % Expand to full settings gamut
    adj = max([settingsLow; settingsHigh]);
    settingsHigh = settingsHigh/adj;
    settingsLow = settingsLow/adj;

    % Re-center the modulation
    adj = obj.modResult.settingsBackground - (settingsHigh+settingsLow)/2;
    settingsHigh = settingsHigh + adj;
    settingsLow = settingsLow + adj;

end

% Numerical imprecision can lead to the settings being slightly outside of
% range. Fix this.
settingsLow(settingsLow>1)=1;
settingsLow(settingsLow<0)=0;
settingsHigh(settingsHigh>1)=1;
settingsHigh(settingsHigh<0)=0;

% Store the adjusted settings
modResult = obj.modResult;
modResult.settingsHigh = settingsHigh;
modResult.settingsLow = settingsLow;

% Update the SPDs and calculated contrast values
modResult = updateModResult(modResult);


end