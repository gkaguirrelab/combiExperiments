% Convert a log NDF measurement number to a string 
% according to the lab conventions of 
% decimals indicated by 0xN
function string = ndf2str(ndf)
    
    string = strrep(num2str(ndf), '.','x');

end