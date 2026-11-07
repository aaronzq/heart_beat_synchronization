function [energy] = getRelativeShiftMatchEnergy(s)
% GETRELATIVESHIFTMATCHENERGY Sum squared pixel differences for shift s.
% s is an integer number of frames. Globals images1/images2 have dimensions
% [height,width,frame]; global startIndex defines the comparison window.
% Compares images1(:,:,j) with images2(:,:,j+s) for
% j = startIndex:3*startIndex-1. Out-of-range frames in images2 are skipped;
% the score is not normalized by the number of comparisons.
% The caller must provide enough frames in images1.

    global images1;
    global images2;
    global startIndex;
    
    [height, width, numOfImages1] = size(images1);
    [height, width, numOfImages2] = size(images2);
 
    energy = 0;
    buffer = zeros(height,width); % per-pixel squared image differences
    
    for i = startIndex:3*startIndex-1
        
        if s+i <= numOfImages2 
       
            buffer = images1(:,:,i) - images2(:,:,s+i);
            buffer = buffer.^2;

            energy = energy + sum(sum(buffer)); 
        end
    end
    

