function yFit = tpupModel(stimulus,stimTime,params)
%
%
%{
    stimulus = [ones(1,1000) zeros(1,1000)];
    stimulus(1:100) = (cos(linspace(pi,0,100))+1)/2;
    stimulus(901:1000) = (cos(linspace(0,pi,100))+1)/2;
    stimTime = linspace(0,24,2000);
    params = [0,2,10,0.5,2,2];
    yFit = tpupModel(stimulus,stimTime,params);
    plot(stimTime,yFit)
%}


delay=params(1);
gammaTau=params(2);
exponentialTau=params(3);
amplitudeTransient=params(4);
amplitudeSustained=params(5);
amplitudePersistent=params(6);

stimulusSlewOn = max( [ [diff(stimulus) 0]; zeros(1,length(stimulus)) ] );

nSamples = length(stimTime);
deltaT = stimTime(2)-stimTime(1);
gammaIRF = (stimTime-min(stimTime)) .* exp(-(stimTime-min(stimTime))./gammaTau);
%gammaIRF = -gampdf(stimTime-min(stimTime),gammaTau);
gammaIRF = gammaIRF / (sum(abs(gammaIRF))*deltaT);




% Create the exponential kernel
exponentialIRF = -exp(-1/exponentialTau*stimTime);
exponentialIRF = exponentialIRF / (sum(abs(exponentialIRF))*deltaT);

transientComponent = -conv(stimulusSlewOn,gammaIRF);
transientComponent = transientComponent / (sum(abs(transientComponent))*deltaT);
transientComponent = transientComponent(1:nSamples);

sustainedComponent = -conv(stimulus,gammaIRF);
sustainedComponent = sustainedComponent / (sum(abs(sustainedComponent))*deltaT);
sustainedComponent = sustainedComponent(1:nSamples);

persistentComponent = conv(conv(stimulusSlewOn,exponentialIRF),gammaIRF);
persistentComponent = persistentComponent / (sum(abs(persistentComponent))*deltaT);
persistentComponent = persistentComponent(1:nSamples);

yFit = amplitudeTransient * transientComponent + ...
    amplitudeSustained * sustainedComponent + ...
    amplitudePersistent * persistentComponent;

yFit = fshift(yFit,delay/deltaT);


end



