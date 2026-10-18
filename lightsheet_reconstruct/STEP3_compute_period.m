%% STEP3_compute_period.m
% Estimate the cardiac period of every light-sheet slice and average them.
%
% Algorithm: directly calls utils/getPeriod_wrapper.m (which calls
% utils/getPeriod.m and utils/getPeriodMatchEnergy.m), exactly as
% STEP2_sync_ls_lf.m did. No light-field information is involved.

clear all; close all; clc;

stepDir = fileparts(mfilename('fullpath'));
if isempty(stepDir)
    stepDir = pwd;
end
load(fullfile(stepDir,'ls_recon_para.mat'));
addpath(utilsDir);

%% Check the number of frames of each slice
for i = 1:numOfSlice
    imageList = dir(fullfile(lsSourcePath,int2str(i),'*.tif'));
    if isempty(imageList)
        error('No tif files found in slice folder: %s', ...
            fullfile(lsSourcePath,int2str(i)));
    end
    if numel(imageList) < numOfImage
        error('Slice %d contains %d tif files, expected at least %d.', ...
            i, numel(imageList), numOfImage);
    end
end

%% Period estimation (same call as the original STEP2_sync_ls_lf.m)
fprintf('Estimating heartbeat period in [%.2f, %.2f] ms ...\n', periodTh1, periodTh2);

t_p_candidate = zeros(1,numOfSlice);
if useParallel
    parfor i = 1:numOfSlice
        t_p_candidate(i) = getPeriod_wrapper( ...
            fullfile(lsSourcePath,int2str(i)), h_T, periodTh1, periodTh2);
    end
else
    for i = 1:numOfSlice
        t_p_candidate(i) = getPeriod_wrapper( ...
            fullfile(lsSourcePath,int2str(i)), h_T, periodTh1, periodTh2);
        fprintf('  slice %3d/%3d : T_p = %9.4f ms\n', ...
            i, numOfSlice, t_p_candidate(i));
    end
end

t_p = sum(t_p_candidate)/length(t_p_candidate);

save(paraFile,'t_p_candidate','t_p','-append');

fprintf('Mean period T_p = %.4f ms (%.4f frames at h_T = %.4f ms)\n', ...
    t_p, t_p/h_T, h_T);
fprintf('STEP3_compute_period finished. Run STEP4_compute_phase next.\n');
