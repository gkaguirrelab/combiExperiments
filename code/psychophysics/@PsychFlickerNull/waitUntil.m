function waitUntil(obj,stopTimeMicroSeconds)


% Enter a while loop
stillWaiting = true;
while stillWaiting
    if tic()>stopTimeMicroSeconds
        stillWaiting = false;
    end
end


end