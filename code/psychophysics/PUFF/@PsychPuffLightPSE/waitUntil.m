function waitUntil(obj,stopTimeSeconds)


% Enter a while loop
stillWaiting = true;
while stillWaiting
    if cputime()>stopTimeSeconds
        stillWaiting = false;
    end
end


end