%% STEP2_prepare_ls_data.m
% Build the light-sheet-only working data root used by the reconstruction.
%
% Compared with STEP1_rename_folders_pre_run.m of the original pipeline:
%   * no light-field reference stack is inserted;
%   * the raw light-sheet folders (rawFirstSlice ... rawLastSlice) are copied
%     to lsSourcePath\1 ... lsSourcePath\numOfSlice without any LF slice.
%
% utils/getRelativeShift_wrapper.m addresses the slices as
% baseDir\int2str(index), therefore the working root must use 1..N names.

clear all; close all; clc;

stepDir = fileparts(mfilename('fullpath'));
if isempty(stepDir)
    stepDir = pwd;
end
load(fullfile(stepDir,'ls_recon_para.mat'));
addpath(utilsDir);

if ~prepareData
    fprintf('prepareData = false: use the existing root %s\n', lsSourcePath);
    fprintf('STEP2_prepare_ls_data finished.\n');
    return;
end

% Never copy a folder tree onto itself.
if strcmpi(regexprep(rawLsPath,'[\\/]+$',''), regexprep(lsSourcePath,'[\\/]+$',''))
    error('rawLsPath and lsSourcePath must be different folders.');
end

if exist(lsSourcePath,'dir') ~= 7
    mkdir(lsSourcePath);
end

fprintf('Copying light-sheet data (no LF reference slice):\n');
for i = 1:numOfSlice

    srcDir = fullfile(rawLsPath,int2str(rawFirstSlice+i-1));
    dstDir = fullfile(lsSourcePath,int2str(i));

    imageList = dir(fullfile(srcDir,'*.tif'));
    if numel(imageList) < numOfImage
        error('Slice %d (%s) contains %d tif files, expected numOfImage = %d.', ...
            i, srcDir, numel(imageList), numOfImage);
    end

    if exist(dstDir,'dir') == 7
        if overwriteOutput
            rmdir(dstDir,'s');
        else
            error('Destination folder already exists: %s (set overwriteOutput = true)', dstDir);
        end
    end
    mkdir(dstDir);

    for j = 1:numOfImage
        copyfile(fullfile(srcDir,imageList(j).name), ...
            fullfile(dstDir,imageList(j).name));
    end

    fprintf('  slice %3d/%3d : %s -> %s (%d frames)\n', ...
        i, numOfSlice, srcDir, dstDir, numOfImage);
end

fprintf('STEP2_prepare_ls_data finished. Run STEP3_compute_period next.\n');
