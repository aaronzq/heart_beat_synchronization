%% STEP1_init.m
% Light-sheet (LS) only reconstruction: initialise all user parameters.
%
% This pipeline is decoupled from the light-field (LF) branch:
%   * no LF reference stack is inserted into / read from the data root;
%   * no LF-LS spatial registration (trans_matrix.mat) is applied.
% Every processing step calls the existing functions in ../utils directly;
% no new reconstruction algorithm is introduced here.
%
% Usage: edit this file, then run ls_reconstruct.m (or STEP2 ... STEP6).

clear all; close all; clc;

%% ------------------------------------------------------------------
% 0. Directories
%% ------------------------------------------------------------------
stepDir = fileparts(mfilename('fullpath'));
if isempty(stepDir)
    stepDir = pwd;
end
repoRoot = fileparts(stepDir);
utilsDir = fullfile(repoRoot,'utils');
if exist(utilsDir,'dir') ~= 7
    error('utils folder not found: %s', utilsDir);
end
addpath(utilsDir);

%% ------------------------------------------------------------------
% 1. File paths
%% ------------------------------------------------------------------
% Original light-sheet acquisition: one sub-folder per scanned slice,
% numbered continuously from rawFirstSlice (e.g. 11,12,...,93).
rawLsPath     = 'E:\research\dataset\zebrafish-heartbeat';
rawFirstSlice = 1;

% Data root read by the reconstruction. It must contain the sub-folders
% '1','2',...,numOfSlice, because utils/getRelativeShift_wrapper.m builds
% the slice paths with int2str(index).
%   prepareData = true  -> STEP2 copies rawLsPath\rawFirstSlice... into it
%   prepareData = false -> it has to exist already
lsSourcePath = 'E:\research\dataset\zebrafish-heartbeat';

% Output root (per-slice sequences, per-state stacks, xyzt volumes).
outputPath = 'E:\research\dataset\zebrafish-heartbeat/recon';

% Parameter file shared by all steps (written by this script).
paraFile = fullfile(stepDir,'ls_recon_para.mat');

%% ------------------------------------------------------------------
% 2. Acquisition parameters
%% ------------------------------------------------------------------
numOfSlice = 65;   % number of scanned slices (z dimension)
numOfImage = 400;  % number of images recorded for EACH slice
h_T        = 5;    % exposure / frame interval of one light-sheet image (ms)

%% ------------------------------------------------------------------
% 3. Heartbeat parameters (same meaning as in STEP2_sync_ls_lf.m)
%% ------------------------------------------------------------------
numOfPeriod        = 2;    % how many cardiac periods are exported
maxSliceConsidered = 2;    % maximal slice distance used in the phase fit
systolicPoint_1st  = 313;   % frame index of the 1st systolic point
systolicPoint_4st  = 624;  % frame index of the 4th systolic point
periodScaleLow     = 0.85; % lower bound factor of the period search window
periodScaleHigh    = 1.15; % upper bound factor of the period search window
periodMargin       = 30;   % extra margin of the period search window (ms)
phaseWeight        = 0.8;  % weight of high-order differences (matrix W)

%% ------------------------------------------------------------------
% 4. Data preparation
%% ------------------------------------------------------------------
prepareData = false;  % true : copy the raw LS slices to lsSourcePath\1..N
                      %        (only light-sheet data, no LF reference slice)
                      % false: lsSourcePath already contains 1..numOfSlice

%% ------------------------------------------------------------------
% 5. Output / geometry options
%% ------------------------------------------------------------------
overwriteOutput = true;  % delete outputPath before writing
useParallel     = false; % parfor gives identical results, but every worker
                         % loads complete slice sequences as double, which is
                         % very memory demanding -> serial by default
saveByState     = true;  % write outputPath\byState\<state>\slice_<i>.tif
saveVolumes     = true;  % write outputPath\xyzt\state_<state>.tif
% Orientation conventions inherited from STEP2_sync_ls_lf.m where they were
% used to co-locate LS with LF. Keep them if the output must have the same
% orientation as the original fused pipeline; set to false for the native
% light-sheet orientation.
% Both flags only affect the xyzt assembly (STEP6), never bySlice / byState,
% so after changing them an existing output can be re-assembled with
% assemble_xyzt_from_byState.m instead of re-running STEP1 ... STEP6.
mirrorXY = false;         % fliplr every slice (LS camera is mirrored)
flipZ    = false;         % flip z (LS depth orientation is opposite)

%% ------------------------------------------------------------------
% 6. Derived parameters and checks
%% ------------------------------------------------------------------
periodTh1 = (systolicPoint_4st-systolicPoint_1st)/3*h_T*periodScaleLow  - periodMargin;
periodTh2 = (systolicPoint_4st-systolicPoint_1st)/3*h_T*periodScaleHigh + periodMargin;
rawLastSlice = rawFirstSlice + numOfSlice - 1;

if ~isscalar(numOfSlice) || numOfSlice < 3 || numOfSlice ~= fix(numOfSlice)
    error('numOfSlice must be an integer >= 3.');
end
if ~isscalar(numOfImage) || numOfImage < 1 || numOfImage ~= fix(numOfImage)
    error('numOfImage must be a positive integer.');
end
if h_T <= 0
    error('h_T must be positive (ms).');
end
if numOfPeriod <= 0
    error('numOfPeriod must be positive.');
end
if maxSliceConsidered < 1 || maxSliceConsidered >= numOfSlice || ...
        maxSliceConsidered ~= fix(maxSliceConsidered)
    error('maxSliceConsidered must be an integer in [1, numOfSlice-1].');
end
if systolicPoint_4st <= systolicPoint_1st
    error('systolicPoint_4st must be larger than systolicPoint_1st.');
end
if periodTh1 <= 0 || periodTh2 <= periodTh1
    error('Invalid period search window: check systolic points / h_T / margins.');
end
if phaseWeight <= 0
    error('phaseWeight must be positive.');
end
if ~saveByState && ~saveVolumes
    error('At least one of saveByState / saveVolumes must be true.');
end

% Make sure that deleting outputPath can never delete the input data.
outKey = lower(regexprep(outputPath,'[\\/]+$',''));
lsKey  = lower(regexprep(lsSourcePath,'[\\/]+$',''));
rawKey = lower(regexprep(rawLsPath,'[\\/]+$',''));
if strcmp(outKey,lsKey) || strncmp(lsKey,[outKey filesep],numel(outKey)+1)
    error('outputPath must not be lsSourcePath or one of its parents.');
end
if strcmp(outKey,rawKey) || strncmp(rawKey,[outKey filesep],numel(outKey)+1)
    error('outputPath must not be rawLsPath or one of its parents.');
end

if isempty(lsSourcePath)
    error('lsSourcePath must be set to an absolute folder containing sub-folders 1..numOfSlice.');
end

if prepareData
    if exist(rawLsPath,'dir') ~= 7
        error('rawLsPath not found: %s', rawLsPath);
    end
    for i = 1:numOfSlice
        srcDir = fullfile(rawLsPath,int2str(rawFirstSlice+i-1));
        if exist(srcDir,'dir') ~= 7
            error('Raw LS slice folder not found: %s', srcDir);
        end
    end
else
    if exist(lsSourcePath,'dir') ~= 7
        error(['lsSourcePath not found: %s\n' ...
               'Set prepareData=true to create it from rawLsPath.'], lsSourcePath);
    end
    for i = 1:numOfSlice
        srcDir = fullfile(lsSourcePath,int2str(i));
        if exist(srcDir,'dir') ~= 7
            error(['Slice folder not found: %s\n' ...
                   'lsSourcePath must contain sub-folders 1..numOfSlice ' ...
                   'because utils/getRelativeShift_wrapper.m uses int2str(index).'], srcDir);
        end
    end
end

if useParallel && isempty(ver('parallel'))
    warning('Parallel Computing Toolbox not found: useParallel is set to false.');
    useParallel = false;
end

save(paraFile, ...
    'rawLsPath','rawFirstSlice','rawLastSlice','lsSourcePath', ...
    'outputPath','paraFile','repoRoot','utilsDir', ...
    'numOfSlice','numOfImage','h_T', ...
    'numOfPeriod','maxSliceConsidered','systolicPoint_1st','systolicPoint_4st', ...
    'periodScaleLow','periodScaleHigh','periodMargin','phaseWeight', ...
    'periodTh1','periodTh2','prepareData', ...
    'overwriteOutput','useParallel','saveByState','saveVolumes', ...
    'mirrorXY','flipZ', '-v7.3');

fprintf('\n--- light-sheet reconstruction parameters ---\n');
fprintf('LS data root      : %s\n', lsSourcePath);
fprintf('Output root       : %s\n', outputPath);
fprintf('Slices            : %d (raw folders %d..%d)\n', numOfSlice, rawFirstSlice, rawLastSlice);
fprintf('Frames per slice  : %d\n', numOfImage);
fprintf('Frame interval    : %.4f ms\n', h_T);
fprintf('Period search     : %.2f .. %.2f ms\n', periodTh1, periodTh2);
fprintf('Periods exported  : %d\n', numOfPeriod);
fprintf('Parallel loop     : %d\n', useParallel);
fprintf('Parameter file    : %s\n\n', paraFile);
fprintf('STEP1_init finished. Run STEP2_prepare_ls_data next.\n');
