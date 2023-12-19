

function  f_capturekeystroke(H,E)
% Get the keystroke
S2 = guidata(H);
set(S2.tx,'string',E.Key)
% Pass it back to the calling function
assignin('caller','currKeyPress',E.Key)
end