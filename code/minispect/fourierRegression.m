function [r2,amplitude,phase,fit,modelT,signalT] = fourierRegression( signal, f0, fps, fpsModel )
% Brief one line description of the function
%
% Syntax:
%   output = myFunc(input)
%
% Description:
%   Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aenean euismod
%   nulla a tempor scelerisque. Maecenas et lobortis est. Donec et turpis
%   sem. Sed fringilla in metus ut malesuada. Pellentesque nec eros
%   efficitur, pellentesque nisl vel, dapibus felis. Morbi eu gravida enim.
%   Sed sodales ipsum eget finibus dapibus. Fusce sagittis felis id orci
%   egestas, non convallis neque porttitor. Proin ut mi augue. Cras posuere
%   diam at purus dignissim, vel vestibulum tellus ultrices
%
% Inputs:
%   none
%   foo                   - Scalar. Foo foo foo foo foo foo foo foo foo foo
%                           foo foo foo foo foo foo foo foo foo foo foo foo
%                           foo foo foo
%
% Optional key/value pairs:
%   none
%  'bar'                  - Scalar. Bar bar bar bar bar bar bar bar bar bar
%                           bar bar bar bar bar bar bar bar bar bar bar bar
%                           bar bar bar bar bar bar
%
% Outputs:
%   none
%   baz                   - Cell. Baz baz baz baz baz baz baz baz baz baz
%                           baz baz baz baz baz baz baz baz baz baz baz baz
%                           baz baz baz
%
% Examples:
%{
	foo = 1;
    bar = myFunc(foo);
	fprintf('Bar = %d \n',bar);   
%}


arguments
    signal (1,:) {mustBeFloat}
    f0 (1,1) {mustBeNumeric}
    fps (1,1) {mustBeNumeric}
    fpsModel (1,1) {mustBeNumeric} = 10000;
end

% Define some aspects of temporal support
deltaT = 1/fps;
modelDeltaT = 1/fpsModel;
elapsed_seconds = length(signal)*deltaT;
signalT = 0:deltaT:elapsed_seconds - deltaT; 
modelT = 0:modelDeltaT:elapsed_seconds - modelDeltaT; 

% Set up the regression matrix
X = [];
X(:,1) = sin(  modelT./(1/f0).*2*pi );
X(:,2) = cos(  modelT./(1/f0).*2*pi );

% Perform the fit
y = interp1(signalT,signal,modelT,'nearest','extrap')';
b = X\y;

% Derive some results
fit = X * b;  % high temporal resolution fit,

amplitude  = norm(b);
phase = -atan(b(2)/b(1));
r2 = corr(fit,y)^2;

end