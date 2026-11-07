%% LS_RECONSTRUCT Synchronize an already arranged light-sheet dataset.
% Edit STEP1_init.m, then run this script from the repository root.
% Runs initialization, period estimation, phase estimation, frame alignment,
% and volume assembly. Input folders must already be numbered 1..numOfSlice.
% No preprocessing or light-field registration is invoked.
% Each STEP script clears the workspace and loads/saves ls_recon_para.mat.
% See README.md for input requirements, output layout, and overwrite behavior.

stepDir = fileparts(mfilename('fullpath'));
if isempty(stepDir)
    stepDir = pwd;
end
addpath(stepDir);

STEP1_init;
STEP2_compute_period;
STEP3_compute_phase;
STEP4_align_slices;
STEP5_assemble_xyzt;

fprintf('\nAll light-sheet reconstruction steps finished.\n');
