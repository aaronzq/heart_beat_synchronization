% STEP4_ALIGN_SLICES Write the phase-aligned sequence at each depth.
% Prerequisite: STEP3_compute_phase; reads t and timePointNum from MAT.
% Selects frames t(i)+1 through t(i)+timePointNum in layer i, without
% resampling or registration, and writes uint16 images to
% outputPath/bySlice/<slice>/<zero-padded-state>.tif.
% Appends bySliceDir to ls_recon_para.mat.
% Deletes the entire existing outputPath when overwriteOutput is true.

clear all; close all; clc;

stepDir = fileparts(mfilename('fullpath'));
if isempty(stepDir)
    stepDir = pwd;
end
load(fullfile(stepDir,'ls_recon_para.mat'));

if ~exist('t','var') || ~exist('timePointNum','var') || isempty(t)
    error('t / timePointNum not found. Run STEP3_compute_phase first.');
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
fprintf('STEP4_align_slices finished. Run STEP5_assemble_xyzt next.\n');
