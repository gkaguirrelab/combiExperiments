function createAdjustedModResult(obj)

% Get the source mod
modResult = obj.sourceModResult;

% Get the current adjustment weight
adjustWeight = obj.adjustWeight;

% Extract the settings
settingsHigh = modResult.settingsHigh;
settingsLow = modResult.settingsLow;
settingsBackground = modResult.settingsBackground;

% Obtain the differential settings for the silencing modulation
silencingDirection = obj.silencingModResult.settingsHigh - ...
    obj.silencingModResult.settingsBackground;

% Add the weighted silencing direction to the modulation settings,
% performing an asymmetric adjustment if requested
highDirection = settingsHigh - settingsBackground;
adjustedHighDirection = highDirection + silencingDirection .* adjustWeight;
settingsHigh = settingsBackground + adjustedHighDirection;
if ~obj.asymmetricAdjustFlag
    LowDirection = settingsLow - settingsBackground;
    adjustedLowDirection = LowDirection + silencingDirection .* adjustWeight;
    settingsLow = settingsBackground + adjustedLowDirection;
end

% Store the settings
modResult.settingsHigh = settingsHigh;
modResult.settingsLow = settingsLow;

% Update the SPDs and calculated contrast values
modResult = updateModResult(modResult);

% Store the adjusted mod result
obj.adjustedModResult = modResult;

end