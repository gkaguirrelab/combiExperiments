function fps = findObservedFPS( signal, f0, fps0 )
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
    signal (1,:) {mustBeNumeric}
    f0 (1,1) {mustBeNumeric}
    fps0 (1,1) {mustBeNumeric}
end

% Cast the signal as a float
signal = double(signal);

% Mean center the signal
sig_mean = mean(signal);
signal = signal - mean(signal);

% Define an objective
myObj = @(x) -fourierRegression( signal, f0, x );

% Set the bounds
lb = 203;
ub = 206.66;

% Search
options = optimoptions('fmincon');
options.Display = 'off';
fps = fmincon(myObj,fps0,[],[],[],[],lb,ub,[],options);

end
