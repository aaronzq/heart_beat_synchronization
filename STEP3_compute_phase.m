% STEP3_COMPUTE_PHASE Estimate integer-frame offsets between depth layers.
% Prerequisite: STEP2_compute_period; reads t_p and configuration from MAT.
% Measures signed pair shifts, solves the original weighted system A*t=-s,
% wraps offsets to one period, and floors them to integer frames.
% Appends shiftList, t, timePointNum, and maxTermInS to ls_recon_para.mat.
% Layer 1 is the zero-phase reference, not a named biological phase.
% See README.md for pair selection, sign convention, and recording length.

clear all; close all; clc;

stepDir = fileparts(mfilename('fullpath'));
if isempty(stepDir)
    stepDir = pwd;
end
load(fullfile(stepDir,'ls_recon_para.mat'));
addpath(utilsDir);

if ~exist('t_p','var') || isempty(t_p)
    error('t_p not found. Run STEP2_compute_period first.');
end
if numOfSlice <= maxSliceConsidered
    error('numOfSlice must be larger than maxSliceConsidered.');
end

% utils/getRelativeShiftMatchEnergy.m compares frames startIndex : 3*startIndex-1,
% so enough frames must exist in every slice.
startIndex = floor(t_p/h_T) + 1;
if 3*startIndex-1 > numOfImage
    error(['The relative-shift search needs frames up to 3*startIndex-1 = %d, ' ...
           'but numOfImage = %d. Increase numOfImage or check t_p / h_T.'], ...
           3*startIndex-1, numOfImage);
end

%% Build the slice pairs used by the original algorithm
maxTermInS = (numOfSlice - maxSliceConsidered) * maxSliceConsidered;
deltaSList = zeros(maxTermInS,1);
indexSList = zeros(maxTermInS,1);
for k = 1:maxTermInS
    deltaSList(k) = floor((k-1)/(numOfSlice-maxSliceConsidered)) + 1;
    indexSList(k) = mod(k,(numOfSlice-maxSliceConsidered));
    if indexSList(k) == 0
        indexSList(k) = numOfSlice - maxSliceConsidered;
    end
end

%% Relative shift between slice i and slice i+deltaS
fprintf('Estimating relative shifts for %d slice pairs ...\n', maxTermInS);
shiftList = zeros(maxTermInS,1);
if useParallel
    parfor k = 1:maxTermInS
        shiftList(k) = getRelativeShift_wrapper(lsSourcePath, ...
            indexSList(k), indexSList(k)+deltaSList(k), t_p, h_T);
    end
else
    for k = 1:maxTermInS
        shiftList(k) = getRelativeShift_wrapper(lsSourcePath, ...
            indexSList(k), indexSList(k)+deltaSList(k), t_p, h_T);
        fprintf('  pair %3d/%3d : slice %3d vs %3d -> shift %+d frames\n', ...
            k, maxTermInS, indexSList(k), indexSList(k)+deltaSList(k), shiftList(k));
    end
end

%% Weighted least-squares system (identical to STEP2_sync_ls_lf.m)
A = zeros(maxTermInS+1, numOfSlice);
s = zeros(maxTermInS+1, 1);
W = zeros(maxTermInS+1, maxTermInS+1);
A(1,1) = 1; W(1,1) = 1; s(1) = 0;

weight = phaseWeight;
for k = 1:maxTermInS
    deltaS = deltaSList(k);
    indexS = indexSList(k);

    temp = zeros(1, numOfSlice);
    temp(indexS) = 1;
    temp(indexS+deltaS) = -1;

    temp2 = zeros(1, maxTermInS+1);
    temp2(k+1) = weight * 0.1^(deltaS-1);

    A(k+1,:) = temp;
    s(k+1,:) = shiftList(k);
    W(k+1,:) = temp2;
end

t = -inv(A'*W'*W*A) * A'*W'*W*s;
t(1) = 0;
t = mod(t, t_p/h_T);
t = floor(t);
timePointNum = floor(numOfPeriod*floor(t_p/h_T));

%% Checks before writing any image
if timePointNum < 1
    error('timePointNum = %d. Check numOfPeriod / t_p / h_T.', timePointNum);
end
for i = 1:numOfSlice
    if t(i) + timePointNum > numOfImage
        error(['Slice %d needs frames %d..%d, but numOfImage = %d.\n' ...
               'Reduce numOfPeriod or increase numOfImage.'], ...
               i, t(i)+1, t(i)+timePointNum, numOfImage);
    end
end

save(paraFile,'maxTermInS','shiftList','t','timePointNum','-append');

fprintf('Phase estimation finished: t_p = %.4f ms, timePointNum = %d frames.\n', ...
    t_p, timePointNum);
for i = 1:numOfSlice
    fprintf('  slice %3d : phase = %4d frames (start frame %4d)\n', ...
        i, t(i), t(i)+1);
end
fprintf('STEP3_compute_phase finished. Run STEP4_align_slices next.\n');
