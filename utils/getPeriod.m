function [T_p] = getPeriod(th1,th2)
% GETPERIOD Minimize the phase-folded image-dispersion objective.
% T_p = getPeriod(th1, th2) returns a period in milliseconds.
% th1/th2 are lower/upper bounds in ms. getPeriodMatchEnergy reads globals
% images [height,width,frame] and h_T (ms), set by getPeriod_wrapper.
% Uses MATLAB fminbnd with its default options.

    T_p = fminbnd(@getPeriodMatchEnergy, th1, th2); % matlab build in non linear optimization function
    
    
    
