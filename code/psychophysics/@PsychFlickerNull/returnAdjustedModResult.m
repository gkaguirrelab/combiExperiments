function modResult = returnAdjustedModResult(obj,adjustWeight)

% Get the source mod
modResult = obj.sourceModResult;

% Extract the settings
settingsHigh = modResult.settingsHigh;
settingsLow = modResult.settingsLow;

% Obtain the differential settings for the silencing modulation
silencingDirection = obj.silencingModResult.settingsHigh - ...
    obj.silencingModResult.settingsBackground;

% Add the weighted silencing direction to the modulation settings,
% performing an asymmetric adjustment if requested
settingsHigh = settingsHigh + silencingDirection .* adjustWeight;
if ~obj.asymmetricAdjustFlag
    settingsLow = settingsLow - silencingDirection .* adjustWeight;
end

% Store the settings
modResult.settingsHigh = settingsHigh;
modResult.settingsLow = settingsLow;

% Update the SPDs and calculated contrast values
modResult = updateModResult(modResult);

end