# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Nextflow pipeline for processing large mouse brain CZI (Zeiss) microscopy files. The pipeline performs image stitching using BigStitcher (Fiji/ImageJ), followed by brain registration to atlases using BrainGlobe's brainreg tools.

## Running the Pipeline

### Recommended Usage (with brain_id)

The simplest way to run the pipeline uses `--brain_id` and `--user_name`:

```bash
# Single brain
nextflow run main.nf -resume -profile slurm --brain_id MS181 --user_name Lana_Smith -with-trace

# Multiple brains
nextflow run main.nf -resume -profile slurm --brain_id MS181,LS010 --user_name Lana_Smith -with-trace
```

This automatically constructs paths based on the data layout:
- **Input**: `<ssh_host>:<input_base_path>/<brain_id>/Anatomy/<brain_id>.czi`
- **Output**: `<ssh_host>:<output_base_path>/<user_name>/<brain_id>/`

The `ssh_host`, `input_base_path`, and `output_base_path` are configured in `nextflow.config` and rarely need overriding.

### Local Execution

```bash
nextflow run main.nf -resume -profile local --input /path/to/file.czi -with-trace
```

### Multiple Files (explicit paths)

```bash
nextflow run main.nf -resume -profile local --input /path/to/file1.czi,/path/to/file2.czi -with-trace
```

### SLURM Cluster Execution

```bash
# Start a screen session (required for long-running transfers)
screen -S register_brains_0

# Load Java module
module load openjdk/21.0.0_35-h27dssk

# Run pipeline on SLURM (recommended: use --brain_id)
nextflow run main.nf -resume -profile slurm --brain_id MS181 --user_name Lana_Smith -with-trace

# Or with explicit SSH path (--user_name still needed for output publishing)
nextflow run main.nf -resume -profile slurm \
  --input user@host:/remote/path/file.czi --user_name Lana_Smith -with-trace
```

### Screen Session Management

```bash
screen -S session_name    # Start new session
screen -ls                # List sessions
screen -r session_name    # Reattach to session
# Ctrl+a d                # Detach from session
```

## Pipeline Architecture

The pipeline follows this processing flow:

1. **Setup & File Staging**
   - `setupFiji()`: Installs Fiji/ImageJ if not cached
   - `stageFilesRSyncSSH()`: Transfers remote files via SSH/rsync to local scratch

2. **BigStitcher Processing** (modules/bigstitcher.nf)
   - `makeCziDatasetForBigstitcher()`: Creates BigStitcher XML from CZI
   - `alignChannelsWithBigstitcher()`: Aligns multi-channel datasets
   - `alignTilesWithBigstitcher()`: Stitches tile positions
   - `icpRefinementWithBigstitcher()`: Refines alignment with ICP algorithm
   - `reorientToASRWithBigstitcher()`: Optional reorientation to ASR coordinates
   - `fuseBigStitcherDataset()`: Fuses into final images (splits by channel)

3. **BrainReg Processing** (modules/brainreg.nf)
   - `brainregEnvInstall()`: Creates Python environment with brainreg
   - `downloadAtlas()`: Downloads brain atlas (cached)
   - `organizeChannelsForBrainreg()`: Separates primary/additional channels
   - `getVoxelSizes()`: Extracts voxel dimensions from BigStitcher XML
   - `brainregRunRegistration()`: Performs atlas registration
   - `copyResultsToImageFolder()`: Transfers results back to original location

4. **Result Publishing** (requires `--user_name`)
   - XML files are published to the output/analysis tree: `<output_base_path>/<user_name>/<brain_id>/`
   - Registration results are published to: `<output_base_path>/<user_name>/<brain_id>/registration/`
   - If `--user_name` is not set, a warning is shown and publishing is disabled

## Key Technical Details

### File Naming and Basenames

The pipeline relies heavily on basename matching to track files through processing stages. All input files **must have unique basenames** (filename without extension). The pipeline strips various suffixes (`_bigstitcher`, `_aligned`, `_tile`, `_icp_refined`, `_asr`) to match files across stages.

### Parameter Sweeps

The pipeline supports parameter sweeps for brainreg registration. Configure in `nextflow.config`:

```groovy
brainreg {
    bending_energy_weight = [0.3, 0.8]    // Multiple values = sweep
    grid_spacing = [4]                     // Single value in brackets = no sweep
    smoothing_sigma_floating = ['-1']      // Can sweep multiple parameters
}
```

The pipeline generates all combinations of sweep parameters and runs registration for each.

### Configuration Profiles

- **local**: Uses Apptainer containers, runs processes locally
- **slurm**: Submits jobs to SLURM cluster with resource allocations
  - Most processes: 64GB RAM, 16 CPUs, 4h
  - Heavy processes (alignChannels, alignTiles, fuse): 400GB RAM, 32 CPUs, 8h on bigmem queue
  - File transfer processes: run locally without SLURM submission

### Cache Directories

Three cache directories avoid re-downloading/re-installing:
- `fiji_cache_dir`: Cached Fiji installation
- `env_cache_dir`: Python brainreg environment
- `atlas_cache_dir`: Downloaded brain atlases

On SLURM, these default to `/work/<group-name>/` for shared access across jobs.

### Memory Management

BigStitcher processes allocate 80% of task memory to Fiji JVM (`--mem` flag), leaving 20% for system overhead.

### Fiji Scripts

ImageJ macro scripts (`.ijm`) and Groovy scripts in `bin/` directory are copied to work directories and executed via Fiji headless mode:

```bash
${FIJI_PATH}/Fiji.app/ImageJ-linux64 --ij2 --headless --console --mem=320000M \
    --run script.ijm 'param1="value1",param2=123'
```

### Channel Processing

The `fuseBigStitcherDataset` always splits output by channel. The `organizeChannelsForBrainreg` process then separates the primary registration channel from additional channels, which are transformed alongside the primary during registration.

### SSH File Transfer

The `stageFilesRSyncSSH` process handles SSH paths (detected by `@` and `:` characters). It uses rsync over SSH with retry logic, progress monitoring, and checksum verification. Node memory is increased to 60GB for large file transfers.

### Cross-Channel Matching

The pipeline uses Nextflow's `.cross()` operator extensively to match processed files back to their original input paths. The matching key is always the basename with all processing suffixes removed.
