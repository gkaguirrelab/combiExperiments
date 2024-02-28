function waitMilliseconds(~,durationToWaitMs)


% Enter a while loop
startTime = datetime();
while milliseconds(datetime()-startTime) < durationToWaitMs
end


end