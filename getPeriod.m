function [T_p] = getPeriod(th1,th2)

% Period Determination

% Parameters Desciption
%   x: horizontal pixel index
%   y: vertical pixel index
%   z: slice index
%   h_T: imaging sampling step
%   T_p: candidate Period.


% Input
%   images: all the images considered
%   h_T: imaging sampling step


% Output
%   T_p: period


%% optimization objective function
    T_p = fminbnd(@getPeriodMatchEnergy, th1, th2); % matlab build in non linear optimization function
    
    
    
