

% "Speed" parameter
speedSetting = 0.99;

% Camera fps
fps = 206.65;

% Range of signal values
signalRange = [0,255];

% Properties of the ramp
rampDurSec = 60;

% Properties of the sinusoid
modDurSecs = 10;
f0 = 0.5;
contrast = 0.5;
backgroundLow = 10^-3;
backgroundMid = 10^-1.5;
backgroundHi = 10^0;

% Properties of the "settle"
settleDurSec = 10;

% Create the sinusoidal modulation
modSourceLow = sin(linspace(0,2*pi*(modDurSecs/(1/f0)),round(fps*modDurSecs))) * contrast * backgroundLow + backgroundLow;
modSourceMid = sin(linspace(0,2*pi*(modDurSecs/(1/f0)),round(fps*modDurSecs))) * contrast * backgroundMid + backgroundMid;
modSourceHi = sin(linspace(0,2*pi*(modDurSecs/(1/f0)),round(fps*modDurSecs))) * contrast * backgroundHi + backgroundHi;

% Assemble the source time series
source = [...
    ones(1,round(fps*settleDurSec))*backgroundHi,... % Start at the high light level;
    logspace(log10(backgroundHi),log10(backgroundLow),round(rampDurSec*fps)), ... % Ramp from the high to the low level
    ones(1,round(fps*settleDurSec))*backgroundHi,... % Settle at the modulation background;
    modSourceHi, ... % The modulation
    ones(1,round(fps*settleDurSec))*backgroundHi, ... % Settle at the modulation background;
    ones(1,round(fps*settleDurSec))*backgroundMid, ... % Settle at the modulation background;
    modSourceMid, ... % The modulation
    ones(1,round(fps*settleDurSec))*backgroundMid, ... % Settle at the modulation background;
    ones(1,round(fps*settleDurSec))*backgroundLow, ... % Settle at the modulation background;
    modSourceLow, ... % The modulation
    ones(1,round(fps*settleDurSec))*backgroundLow, ... % Settle at the modulation background;
    ];

% Define the time domain of the measure
deltaT = 1/fps;
ts = 0:deltaT:(length(source)-1)*deltaT;