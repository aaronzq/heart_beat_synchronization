%% ls_reconstruct.m
% Entry point of the light-sheet-only xyzt reconstruction.
%
% This runner executes STEP1 ... STEP6 in order. Edit the parameters in
% STEP1_init.m before running. The pipeline contains no light-field data and
% no LF-LS registration; all algorithms come from ../utils.
%
% Usage from MATLAB:
%   cd lightsheet_reconstruct
%   ls_reconstruct

stepDir = fileparts(mfilename('fullpath'));
if isempty(stepDir)
    stepDir = pwd;
end
addpath(stepDir);

STEP1_init;
STEP2_prepare_ls_data;
STEP3_compute_period;
STEP4_compute_phase;
STEP5_align_slices;
STEP6_assemble_xyzt;

fprintf('\nAll light-sheet reconstruction steps finished.\n');
