% FINDPERIOD Interactive historical one-layer period estimate.
% Edit the example interval, folder and search bounds (milliseconds).
% Add utils to the MATLAB path first. Calls getPeriod_wrapper and prints ms.
% Not invoked by ls_reconstruct.

h_T = 4;

fileSrc = uigetdir('C:\example_data\light_sheet');

t_p = getPeriod_wrapper(fileSrc, h_T, 303, 480);

fprintf('period is %f\n',t_p); 