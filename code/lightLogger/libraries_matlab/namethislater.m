figure ; 

signal = parse_mean_frame_array_buffer("/Volumes/EXTERNAL1/cpuPriority_5hz_0NDF/cpuPriority_5hz_0NDF_pupil")
signal_contrast = (signal - mean(signal)) / mean(signal)

subsection_begin = 2*60*120;

[r2,amplitude,phase,fit,modelT,signalT] = fourierRegression(signal_contrast(subsection_begin:end), 5, 119.8, 1000 );

plot(signalT, signal_contrast, 'Color', 'blue', '-x', 'DisplayName', 'signal');
hold on; 

plot(signalT, signal_contrast, 'Color', 'orange', '-o', 'DisplayName', 'fit');

amplitude = 0.4; 
sampling_rate = 120;
duration = 60*4;
phaseShift = pi / 2; 

guess_t = 1:1/sampling_rate:duration;
guess_y = amplitude * sin(2 * pi * frequency * guess_t);

plot(guess_t, guess_y, 'DisplayName', 'Guess')
