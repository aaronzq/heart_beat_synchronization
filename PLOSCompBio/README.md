# Hybrid light-field/light-sheet workflow

This directory preserves the previous root scripts for light-sheet/light-field synchronization and spatial registration. The root [light-sheet-only workflow](../README.md) is the entry point for adopters who want to synchronize an already arranged light-sheet dataset.

Research background is summarized at the end of the [root README](../README.md).

| File | Historical role |
| --- | --- |
| [STEP1_rename_folders_pre_run.m](STEP1_rename_folders_pre_run.m) | Copy light-sheet recordings into numbered folders and insert a light-field reference recording; write `sync_para.mat` |
| [STEP2_sync_ls_lf.m](STEP2_sync_ls_lf.m) | Estimate periods and phases, align recordings, and assemble light-sheet volumes with the reference layer excluded |
| [registerXY.m](registerXY.m) | Select corresponding points interactively and save a light-field-to-wide-field similarity transform in `trans_matrix.mat` |
| [STEP3_apply_registration.m](STEP3_apply_registration.m) | Apply the stored spatial transform and temporal offset to reconstructed light-field volumes |
| `sync_para.mat` | Historical synchronization parameters, tied to a previous acquisition |
| `trans_matrix.mat` | Historical calibration transform, tied to a previous acquisition |
| `historical_parameters/ls_recon_para.mat` | Preserved snapshot from the former `lightsheet_reconstruct/` directory; not a reusable default configuration |

These files are retained for provenance. The `.mat` files are not sample image data or valid calibrations for a new experiment. Their original contents are preserved and may contain old paths. The scripts now show example paths and filenames; acquisition and calibration values still require review for any new experiment.

To examine or run the historical workflow, make this directory the MATLAB current folder. The scripts intentionally retain their relative parameter-file loading and saving; shared helper paths point to `../utils`. Recreate acquisition-specific parameters and calibration rather than relying on the archived snapshots. `registerXY.m` and spatial registration use Image Processing Toolbox; the historical synchronization script uses `parfor`.

The historical STEP2 also retains explicit demonstration overrides (`numOfSlice = 3`, `numOfImage = 450`, `refOfLightfield = 2`) after loading parameters. Existing output deletion, prompts, geometry conventions, and calculations are unchanged. These scripts are not invoked by the root runner.
