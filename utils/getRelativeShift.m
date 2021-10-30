% Relative Shift Determination

% Input
%   images: all the images considered
%   h_T: imaging sampling step


% Output
%   Q_i_j: matrix entry storing minimum time shift between slice_i and slice_j 

function [Q_i_j] = getRelativeShift(startIndex_1)

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
    
    
    



