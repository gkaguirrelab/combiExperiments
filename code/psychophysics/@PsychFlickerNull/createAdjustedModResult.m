function modResult = createAdjustedModResult(obj,adjustWeight)

% Get the source mod
modResult = obj.sourceModResult;

% Extract the settings
settingsHigh = modResult.settingsHigh;
settingsLow = modResult.settingsLow;
settingsBackground = modResult.settingsBackground;

% Obtain the differential settings for the silencing modulation
silencingDirection = obj.silencingModResult.settingsHigh - ...
    obj.silencingModResult.settingsBackground;

% Add the weighted silencing direction to the modulation settings
highDirection = settingsHigh - settingsBackground;
adjustedHighDirection = highDirection + silencingDirection .* adjustWeight;
settingsHigh = settingsBackground + adjustedHighDirection;
LowDirection = settingsLow - settingsBackground;
adjustedLowDirection = LowDirection + silencingDirection .* adjustWeight;
settingsLow = settingsBackground + adjustedLowDirection;

% Confirm that we have not taken the settings out of gamut
assert(~any(settingsHigh > 1)); 
assert(~any(settingsLow > 1)); 
assert(~any(settingsHigh < 0)); 
assert(~any(settingsLow < 0)); 

% Store the settings
modResult.settingsHigh = settingsHigh;
modResult.settingsLow = settingsLow;

% Update the SPDs and calculated contrast values
modResult = updateModResult(modResult);

end