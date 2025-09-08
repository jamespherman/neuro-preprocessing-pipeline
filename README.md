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

### 3. Waveform Extraction (Automated)
After spike sorting is complete, the next automated step extracts the mean waveforms for each curated cluster. When `run_preprocessing.m` is executed, it checks for jobs where `kilosort_status` is `complete`, but `waveform_status` is `pending`.

*   It reads the raw broadband (`.ns5`) and Kilosort output files.
*   For each cluster, it extracts a snippet of the waveform for every spike.
*   It calculates the mean and standard deviation of these waveforms.
*   It saves a **preliminary** `session_data.mat` file containing only the `spikes.wfMeans` and `spikes.wfStds` structures.
*   On success, it updates the job's `waveform_status` to `complete`.

### 4. Final Data Consolidation (Automated)
The final step merges the spike times and cluster data (from Kilosort) with the behavioral data (from the preparation step) and the extracted waveforms. When `run_preprocessing.m` is executed, it checks for jobs where `dat_status`, `behavior_status`, `kilosort_status`, and `waveform_status` are all `complete`, but `consolidation_status` is `pending`.

*   It loads the intermediate behavioral data file.
*   It loads the Kilosort output files (`spike_times.npy`, etc.).
*   It loads the mean waveforms from the preliminary `session_data.mat` file created in the previous step.
*   It merges all data sources into a single `session_data` struct.
*   It **overwrites** the preliminary file with the final, complete `[job.unique_id]_session_data.mat`.
*   On success, it updates the job's `consolidation_status` to `complete`.

---

## The `session_manifest.csv` File

This pipeline is controlled by the `config/session_manifest.csv` file. Each row represents a single, atomic unit of work (typically the data from one probe in a recording session).

### Manifest Columns

| Column Name | Description |
| :--- | :--- |
| `unique_id` | A unique identifier for a single recording from a single probe, constructed as `{monkey}_{date}_{brain_area}`. |
| `session_group_id`| An identifier that links multiple recordings from the same day and animal (e.g., from two different probes). |
| `monkey` | The name of the subject monkey (e.g., `Feynman`, `Newton`). |
| `date` | The date of the recording session in `MM_DD_YYYY` format. |
| `experiment_pc_name`| The name of the PC that ran the behavioral task (e.g., `pldaps2`). |
| `probe_type` | The type of neural probe used for the recording (e.g., `nnVector`, `vProbe`). |
| `brain_area` | The targeted brain region for this specific recording (e.g., `SNc`, `SC`). |
| `channel_numbers`| The range of channel numbers on the headstage that correspond to this probe (e.g., `1:32`). |
| `channel_ordering`| A string representing the physical layout and ordering of channels on the probe, used by Kilosort. |
| `raw_filename_base`| The base name of the raw neural data files (e.g., `feynman_08052025_01`). |
| `dat_status` | Status of the `.dat` file conversion step. Values: `pending`, `complete`, `error`. |
| `behavior_status` | Status of the behavioral data preparation step. Values: `pending`, `complete`, `error`. |
| `kilosort_status` | Status of the Kilosort spike sorting step. Values: `pending`, `complete`. |
| `waveform_status` | Status of the mean waveform extraction step. Values: `pending`, `complete`, `error`. |
| `consolidation_status`| Status of the final data consolidation step. Values: `pending`, `complete`, `error`. |
| `notes` | Free-text field for any relevant notes about the session, often including the names of the behavioral tasks. |

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
4.  **Run Pipeline to Consolidate:** Re-run the pipeline script (`>> run_preprocessing`). This will:
    *   Automatically detect Kilosort's completion and update the manifest.
    *   Extract mean waveforms.
    *   Perform the final data consolidation.