h_T = 4;

fileSrc = uigetdir('H:\rawData\cmlc_gfp_gata1_dsred_ctrl_5dpf_20191002_reverse_step\data\');

t_p = getPeriod_wrapper(fileSrc, h_T, 303, 480);

fprintf('period is %f\n',t_p); 