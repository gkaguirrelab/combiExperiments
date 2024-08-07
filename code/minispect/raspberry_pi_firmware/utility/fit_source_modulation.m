
function fit_data = fit_source_modulation(data)
%


% Parse the temp data file
py_data = struct(data);

% Extract relevant information from the struct
signal = double(py_data.signal);
light_level = char(py_data.light_level);
f0 = double(py_data.frequency);
fps = double(py_data.fps);
elapsed_seconds = double(py_data.elapsed_seconds);
secsPerMeasure = double(py_data.secsPerMeasure);

% Perform the fitting routine
signalT = 0:secsPerMeasure:elapsed_seconds-secsPerMeasure; 

sig_mean = mean(signal);
signal = signal - mean(signal);  % freq is the source flicker freq in Hz. Signal is the vector of measures for a channel
% sampling frequency of signal 
fs = 1./secsPerMeasure;
modeldT = 0.001; 
modelT = 0:modeldT:elapsed_seconds - modeldT; 
% Set up the regression matrix
X = [];
X(:,1) = sin(  modelT./(1/f0).*2*pi );
X(:,2) = cos(  modelT./(1/f0).*2*pi );

% Perform the fit
y = interp1(signalT,signal,modelT,'nearest','extrap')';
b = X\y;

fit = X * b;  % high temporal resolution fit,

amplitude  = norm(b);
phase = -atan(b(2)/b(1));


fit_data.signalT = signalT; 
fit_data.signal = signal; 
fit_data.sig_mean = sig_mean; 
fit_data.modelT = modelT; 
fit_data.fit = fit; 
fit_data.amplitude = amplitude; 
fit_data.phase = phase; 


% Plot the signal versus fit values
figure ;

plot(signalT,signal+sig_mean, '-o');
hold on; 
title(sprintf("Source vs Fit %sNDF %0.1fhz", light_level, f0))
plot(modelT,fit+sig_mean, '-o');
xlabel('Time (seconds)');
ylabel('Counts');
legend('Signal','Fit');
hold off; 

pause(10); 

end