pauseTime = 0.25;

pause(2);

for i = 1:3
    system('say "Center"');
    pause(pauseTime);
    system('say "Left"');
    pause(pauseTime);
    system('say "Center"');
    pause(pauseTime);
    system('say "Right"');
    pause(pauseTime);
end
