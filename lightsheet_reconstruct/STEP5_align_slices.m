%% STEP5_align_slices.m
% Cut one phase-aligned image sequence out of every light-sheet slice.
%
% For slice i the frames t(i)+1 ... t(i)+timePointNum are copied (the same
% range as in STEP2_sync_ls_lf.m). No resampling or registration is applied.
%
% Output:
%   outputPath\bySlice\<slice>\<state>.tif

clear all; close all; clc;

stepDir = fileparts(mfilename('fullpath'));
if isempty(stepDir)
    stepDir = pwd;
end
load(fullfile(stepDir,'ls_recon_para.mat'));

if ~exist('t','var') || ~exist('timePointNum','var') || isempty(t)
    error('t / timePointNum not found. Run STEP4_compute_phase first.');
end

%% Prepare the output root
if exist(outputPath,'dir') == 7
    if overwriteOutput
        rmdir(outputPath,'s');
    else
        error('Output folder exists: %s (set overwriteOutput = true)', outputPath);
    end
end
mkdir(outputPath);

bySliceDir = fullfile(outputPath,'bySlice');
mkdir(bySliceDir);

%% Write the aligned sequence of each slice
fprintf('Writing phase-aligned sequences (%d frames per slice):\n', timePointNum);
for i = 1:numOfSlice

    srcDir = fullfile(lsSourcePath,int2str(i));
    imageList = dir(fullfile(srcDir,'*.tif'));
    if t(i) + timePointNum > numel(imageList)
        error('Slice %d has only %d frames, requested frame %d.', ...
            i, numel(imageList), t(i)+timePointNum);
    end

    dstDir = fullfile(bySliceDir,int2str(i));
    mkdir(dstDir);

    for j = 1:timePointNum
        srcFile = fullfile(srcDir,imageList(t(i)+j).name);
        dstFile = fullfile(dstDir,sprintf('%04d.tif',j));
        imwrite(uint16(imread(srcFile)), dstFile);
    end

    fprintf('  slice %3d/%3d : frames %4d..%4d -> %s\n', ...
        i, numOfSlice, t(i)+1, t(i)+timePointNum, dstDir);
end

save(paraFile,'bySliceDir','-append');
fprintf('STEP5_align_slices finished. Run STEP6_assemble_xyzt next.\n');
