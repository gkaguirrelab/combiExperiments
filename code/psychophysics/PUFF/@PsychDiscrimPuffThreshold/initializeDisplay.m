function initializeDisplay(obj)

if isempty(obj.AirPuffObj) && ~obj.simulateStimuli
    if obj.verbose
        fprintf('AirPuffObj is empty; update this property and call the initializeDisplay method');
    end
end

% Ensure that the CombiAir is configured to present our stimuli
% properly (if we are not simulating the stimuli)
if ~obj.simulateStimuli

    % Alert the user
    if obj.verbose
        fprintf('Initializing AirPuffObj\n')
    end

end

end