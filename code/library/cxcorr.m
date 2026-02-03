function [corrVals,lags]=cxcorr(a,b,maxShift)
if nargin == 2
    maxShift = floor(length(b)/2);
end
na=norm(a(~isnan(a)));
nb=norm(b(~isnan(b)));
a=a/na; %normalization
b=b/nb;
for shift=-maxShift:maxShift
    idx = shift+maxShift+1;
    corrVals(idx)=corr(a',circshift(b,shift)','Rows','complete');
    lags(idx)=shift;
end
% % Center the vectors at zeros
% lagBreak = floor(length(lags)/2);
% lags(lags>lagBreak) = lags(lags>lagBreak)-length(lags);
% lags = circshift(lags,-lagBreak-1);
% corrVals = circshift(corrVals,-lagBreak-1);