pauseTime = 2;
recObj = audiorecorder;

disp('Recording started...');
record(recObj);

for i = 1:3
    system('say "Look center"');
    pause(pauseTime);
    system('say "Look left"');
    pause(pauseTime);
    system('say "Look right"');
    pause(pauseTime);
    system('say "Look center"');
    pause(pauseTime);
end

stop(recObj);
disp('Recording stopped.');

% Get the audio data and save it
audioData = getaudiodata(recObj);
Fs = recObj.SampleRate; 
save('EOGCalInstructions.mat', 'audioData', 'Fs');
