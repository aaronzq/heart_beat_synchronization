%% STEP1_INIT Configure an already arranged light-sheet acquisition.
% Edit the example paths and acquisition/heartbeat settings below.
% Input: numbered slice folders of chronologically ordered single-page TIFFs.
% Output: ls_recon_para.mat in this repository, replaced on each initialization.
% Later steps append estimated periods, offsets, and output paths to this file.
% Running this script clears the workspace and closes figures.
% No data preparation is performed. See README.md before running.

clear all; close all; clc;

%% ------------------------------------------------------------------
% 0. Directories
%% ------------------------------------------------------------------
stepDir = fileparts(mfilename('fullpath'));
if isempty(stepDir)
    stepDir = pwd;
end
repoRoot = stepDir;
utilsDir = fullfile(repoRoot,'utils');
if exist(utilsDir,'dir') ~= 7
    error('utils folder not found: %s', utilsDir);
end
addpath(utilsDir);

%% ------------------------------------------------------------------
% 1. File paths
%% ------------------------------------------------------------------
% Already arranged input: one depth per folder, named 1..numOfSlice.
% Use absolute paths. These examples do not refer to bundled data.
lsSourcePath = 'C:\example_data\light_sheet';
% Use a dedicated output folder, separate from the input data.
outputPath = 'C:\example_results\heart_reconstruction';

% Parameter file shared by all steps (written by this script).
paraFile = fullfile(stepDir,'ls_recon_para.mat');

%% ------------------------------------------------------------------
% 2. Acquisition parameters (illustrative values; replace for your recording)
%% ------------------------------------------------------------------
numOfSlice = 10;   % number of scanned slices (z dimension)
numOfImage = 600;  % number of images recorded for EACH slice
h_T        = 5;    % time between successive frames (ms), not exposure alone if gaps exist

%% ------------------------------------------------------------------
% 3. Heartbeat parameters (illustrative systolic indices; replace for your data)
%% ------------------------------------------------------------------
numOfPeriod        = 2;    % how many cardiac periods are exported
maxSliceConsidered = 2;    % maximal slice distance used in the phase fit
systolicPoint_1st  = 100;   % frame index of the 1st systolic point
systolicPoint_4st  = 400;  % frame index of the 4th systolic point
periodScaleLow     = 0.85; % lower bound factor of the period search window
periodScaleHigh    = 1.15; % upper bound factor of the period search window
periodMargin       = 30;   % extra margin of the period search window (ms)
phaseWeight        = 0.8;  % pair-row multiplier; distance d adds a factor 0.1^(d-1)

%% ------------------------------------------------------------------
% 4. Output / geometry options
%% ------------------------------------------------------------------
overwriteOutput = true;  % delete outputPath before writing
useParallel     = false; % parallel loops use the same calculation; every worker
                         % loads complete slice sequences as double, which is
                         % very memory demanding -> serial by default
saveByState     = true;  % write outputPath\byState\<state>\slice_<i>.tif
saveVolumes     = true;  % write outputPath\xyzt\state_<state>.tif
% Orientation conventions inherited from PLOSCompBio/STEP2_sync_ls_lf.m; they were
% used to co-locate LS with LF. Keep them if the output must have the same
% orientation as the original fused pipeline; set to false for the native
% light-sheet orientation.
% Both flags affect only STEP5 volume assembly, never bySlice / byState.
mirrorXY = false;         % fliplr every slice (LS camera is mirrored)
flipZ    = false;         % flip z (LS depth orientation is opposite)

%% ------------------------------------------------------------------
% 5. Derived parameters and checks
%% ------------------------------------------------------------------
periodTh1 = (systolicPoint_4st-systolicPoint_1st)/3*h_T*periodScaleLow  - periodMargin;
periodTh2 = (systolicPoint_4st-systolicPoint_1st)/3*h_T*periodScaleHigh + periodMargin;

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

% Reject direct input/output overlap. Use absolute, unambiguous paths;
% this historical string check does not resolve aliases or parent segments.
outKey = lower(regexprep(outputPath,'[\\/]+$',''));
lsKey  = lower(regexprep(lsSourcePath,'[\\/]+$',''));
if strcmp(outKey,lsKey) || strncmp(lsKey,[outKey filesep],numel(outKey)+1)
    error('outputPath must not be lsSourcePath or one of its parents.');
end

if isempty(lsSourcePath)
    error('lsSourcePath must be set to an absolute folder containing sub-folders 1..numOfSlice.');
end

if exist(lsSourcePath,'dir') ~= 7
    error('lsSourcePath not found: %s. See README.md for the required layout.', lsSourcePath);
end
for i = 1:numOfSlice
    srcDir = fullfile(lsSourcePath,int2str(i));
    if exist(srcDir,'dir') ~= 7
        error('Slice folder not found: %s. Expected folders 1..numOfSlice.', srcDir);
    end
end

if useParallel && isempty(ver('parallel'))
    warning('Parallel Computing Toolbox not found: useParallel is set to false.');
    useParallel = false;
end

save(paraFile, ...
    'lsSourcePath', ...
    'outputPath','paraFile','repoRoot','utilsDir', ...
    'numOfSlice','numOfImage','h_T', ...
    'numOfPeriod','maxSliceConsidered','systolicPoint_1st','systolicPoint_4st', ...
    'periodScaleLow','periodScaleHigh','periodMargin','phaseWeight', ...
    'periodTh1','periodTh2', ...
    'overwriteOutput','useParallel','saveByState','saveVolumes', ...
    'mirrorXY','flipZ', '-v7.3');

fprintf('\n--- light-sheet reconstruction parameters ---\n');
fprintf('LS data root      : %s\n', lsSourcePath);
fprintf('Output root       : %s\n', outputPath);
fprintf('Slices            : %d\n', numOfSlice);
fprintf('Frames per slice  : %d\n', numOfImage);
fprintf('Frame interval    : %.4f ms\n', h_T);
fprintf('Period search     : %.2f .. %.2f ms\n', periodTh1, periodTh2);
fprintf('Periods exported  : %d\n', numOfPeriod);
fprintf('Parallel loop     : %d\n', useParallel);
fprintf('Parameter file    : %s\n\n', paraFile);
fprintf('STEP1_init finished. Run STEP2_compute_period next.\n');
