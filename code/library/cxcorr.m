function [corrVals,lags]=cxcorr(a,b)
na=norm(a(~isnan(a)));
nb=norm(b(~isnan(b)));
a=a/na; %normalization
b=b/nb;
for k=1:length(b)
    corrVals(k)=corr(a',b','Rows','complete');
    b=[b(end),b(1:end-1)]; %circular shift
end
lags=0:length(b)-1; %lags
% Center the vectors at zeros
lagBreak = floor(length(lags)/2);
lags(lags>lagBreak) = lags(lags>lagBreak)-length(lags);
lags = circshift(lags,-lagBreak-1);
corrVals = circshift(corrVals,-lagBreak-1);