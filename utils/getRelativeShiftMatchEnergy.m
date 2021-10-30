 % Despersion Objective Function Calculation

% Parameters Description


% Input
% images: the matrix storing all images of a aticular slice on different
%         time instances
% timeInstances: the array storing the phase locked time indices
%         of all images in the first period
% T_p: period

% Output
% Relative Shift Match Energy

function [energy] = getRelativeShiftMatchEnergy(s)

    global images1;
    global images2;
    global startIndex;
    
    [height, width, numOfImages1] = size(images1);
    [height, width, numOfImages2] = size(images2);
 
    energy = 0;
    buffer = zeros(height,width); % buffer is used to store the intance difference
                                  % of two frames on two adjacent time
                                  % instance 
    
    for i = startIndex:3*startIndex-1
        
        if s+i <= numOfImages2 
       
            buffer = images1(:,:,i) - images2(:,:,s+i);
            buffer = buffer.^2;

            energy = energy + sum(sum(buffer)); 
        end
    end
    

