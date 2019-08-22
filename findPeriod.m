h_T = 5;

fileSrc = uigetdir('F:\hsiailab\rawData\aaron_spim\dichromatic_test_20190506');

t_p = getPeriod_wrapper(fileSrc, h_T, 300, 500);

fprintf('period is %f\n',t_p); 