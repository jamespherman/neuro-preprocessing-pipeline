# Neuro-Preprocessing Pipeline

## Project Goal

This repository contains the MATLAB source code for a preprocessing pipeline designed to convert raw electrophysiology data (from Ripple/PLDAPS systems and Kilosort) into a standardized, analysis-ready format (`session_data.mat`).

## Workflow Overview

The pipeline is driven by the `run_preprocessing.m` script, which reads the `session_manifest.csv` to orchestrate a multi-stage workflow. The processing status for each stage is tracked in its own column in the manifest.

### 1. Data Preparation (Automated)
When `run_preprocessing.m` is executed, it checks for any jobs with a `pending` status in the `dat_status` or `behavior_status` columns.

*   **Spike Data Preparation (`dat_status`)**:
    *   Reads raw broadband data (`.ns5` file).
    *   Slices the data to include only the channels specified in `channel_numbers`.
    *   Writes the result to a binary `.dat` file required for Kilosort.
    *   On success, updates the job's `dat_status` to `complete`.

*   **Behavioral Data Preparation (`behavior_status`)**:
    *   Parses event codes from the `.nev` file to create `trialInfo` and `eventTimes` structures.
    *   Integrates PLDAPS behavioral data (e.g., eye position, joystick data) from `.mat` files.
    *   Saves an intermediate `.mat` file containing this merged behavioral/event data.
    *   On success, updates the job's `behavior_status` to `complete`.

### 2. Spike Sorting (Manual & Automated Check)
This stage bridges a manual sorting process with an automated check.

*   **Manual Sorting**: The user runs Kilosort/Phy on the `.dat` file from the previous stage to sort spikes and perform manual curation.
*   **Automated Status Check**: When `run_preprocessing.m` is run, it checks for the presence of Kilosort output files (e.g., `spike_times.npy`). If found, it automatically updates the job's `kilosort_status` to `complete`.

### 3. Data Consolidation (Future Work)
The final step of merging the spike data (from Kilosort) and the behavioral data (from the preparation step) into the final `session_data.mat` is planned but not yet implemented in `run_preprocessing.m`. The `consolidation_status` column is reserved for tracking this stage.

---

## The `sessions_manifest.csv` File

This pipeline is controlled by the `config/sessions_manifest.csv` file. Each row represents a single, atomic unit of work (typically the data from one probe in a recording session).

### Manifest Columns

| Column Name | Description |
| :--- | :--- |
| `unique_id` | The unique primary key for this job (e.g., `MonkeyA_20250822_SC`). |
| `session_group_id`| An ID to link all probes recorded simultaneously. |
| `monkey` | The name of the subject. |
| `date` | The date of the recording (YYYY-MM-DD). |
| `experiment_pc_name`| The name of the behavioral control PC (`pldaps1` or `pldaps2`). |
| `probe_type` | The type of probe used (e.g., `Plexon V-Probe`). |
| `brain_area` | The brain area targeted by this probe (e.g., `SC`). |
| `channel_numbers`| A MATLAB-readable string defining the channels for this probe (e.g., `'1:32'`). |
| `channel_ordering`| A string defining the probe's physical channel order. |
| `raw_filename_base`| The base name of the raw data files (e.g., `monkeya_08222025_01`). |
| `dat_status` | Status of the raw neural data to binary (`.dat`) conversion. Values: `pending`, `complete`, `error`. |
| `behavior_status` | Status of the behavioral data preparation. Values: `pending`, `complete`, `error`. |
| `kilosort_status` | Status of the manual Kilosort/Phy spike sorting. Values: `pending`, `complete`. |
| `consolidation_status`| Status of the final data consolidation. Values: `pending`, `complete`, `error`. |
| `notes` | Free-text field for comments. |

---

## Directory Structure

-   `/config`: Contains the `sessions_manifest.csv`.
-   `/docs`: Contains supporting documentation, including data dictionaries for the behavioral tasks that describe the structure of the raw PLDAPS `.mat` files.
-   `/functions`: All MATLAB functions, organized into packages (`+utils`, `+prep`, `+consolidate`).
-   `/scripts`: Contains the main entry point for the pipeline, `run_preprocessing.m`.
-   `/pipeline_output`: **(Ignored by Git)** This is the default location for all generated data.

---

## Usage

1.  **Add a Job:** Add a new row to `config/sessions_manifest.csv`. At a minimum, set `dat_status` and `behavior_status` to `pending`.
2.  **Run Preparation:** Execute the master script from the MATLAB command line: `>> run_preprocessing`. This will prepare the spike and behavioral data.
3.  **Perform Manual Sorting:** Run Kilosort/Phy on the generated `.dat` file for the job.
4.  **Check Status:** Re-run the pipeline script (`>> run_preprocessing`) to automatically detect Kilosort's completion and update the manifest.