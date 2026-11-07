function [Q_i_j] = getRelativeShift(startIndex_1)
% GETRELATIVESHIFT Search integer temporal offsets between loaded layers.
% Q_i_j = getRelativeShift(startIndex_1) returns a signed frame shift.
% Reads globals images1/images2 through getRelativeShiftMatchEnergy and
% sets global startIndex = startIndex_1 (normally floor(t_p/h_T)+1).
% Searches -floor((startIndex-1)/2):floor(startIndex/2).
% Equal costs keep the first candidate in this ordered search.

    global startIndex;
    startIndex = startIndex_1;
%% optimization objective function
    cost = inf;
    %for s = 0:startIndex-1
    for s = -floor((startIndex-1)/2):floor(startIndex/2)    
        temp = getRelativeShiftMatchEnergy(s);
        if temp < cost           
            Q_i_j = s;
            cost = temp;
        end
    end
    
    
    



