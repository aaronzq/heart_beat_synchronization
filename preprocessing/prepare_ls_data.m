%% PREPARE_LS_DATA Optional copy/renumber utility; not part of reconstruction.
% Edit the example settings below, then run this script separately.
% Copies the first numOfImage TIFFs (dir order) from rawFirstSlice onward
% into folders 1..numOfSlice. The source images are not modified.
% Existing destination slice folders are deleted when overwriteOutput=true.
% Use separate, nonoverlapping absolute source and destination paths.
% Afterwards set lsSourcePath in the root STEP1_init.m to this destination.
% See preprocessing/README.md for details.

clear all; close all; clc;
rawLsPath = 'C:\example_data\raw_light_sheet';
rawFirstSlice = 11;
lsSourcePath = 'C:\example_data\light_sheet';
numOfSlice = 10;
numOfImage = 600;
overwriteOutput = true; % preserves the original preparation setting

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

fprintf('Preparation finished. Configure and run STEP1_init in the repository root.\n');
