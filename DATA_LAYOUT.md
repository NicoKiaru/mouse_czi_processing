# Data Layout Documentation

## Overview

This document describes the data organization for mouse brain CZI processing in the Petersen Lab at EPFL.

## Input Data Structure

### Base Location
```
/home/lmsmith/servers/data
```

### Directory Structure
```
servers/data/
├── LS001/                    # User folder (initials + 3-digit number)
│   ├── Anatomy/
│   │   └── LS001.czi        # Raw CZI file (named after brain ID)
│   ├── IOS/
│   ├── Recording/
│   ├── SLIMS/
│   └── Training/
├── LS010/
│   └── Anatomy/
│       └── LS010.czi
└── MS181/
    └── Anatomy/
        └── MS181.czi
```

### Naming Conventions

**User Folders:**
- Format: `<Initials><3-digit-number>`
- Examples: `LS001`, `LS010`, `LS132`, `MS181`
- Initials: First letter of first name + first letter of last name (e.g., Lana Smith → LS)

**Brain Data:**
- One `.czi` file per brain in the `Anatomy/` subfolder
- File named according to brain identifier
- Example: `MS181/Anatomy/MS181.czi`

### Access Methods

#### 1. GIO Mount (Slow)
```bash
# Via mounted NAS drive
/home/lmsmith/servers/data/MS181/Anatomy/MS181.czi
```

#### 2. SSH (Fast - Recommended for Pipeline)
```bash
# Via SSH - much faster transfer speed
lmsmith@haas056.rcp.epfl.ch:/mnt/lsens-data/MS181/Anatomy/MS181.czi
```

**Usage in Pipeline:**
```bash
nextflow run main.nf -resume -profile slurm \
  --input lmsmith@haas056.rcp.epfl.ch:/mnt/lsens-data/MS181/Anatomy/MS181.czi
```

### Access Permissions
- ✅ **Write access:** Can create new files
- ❌ **No modification access:** Once a file is written, it cannot be modified
- ⚠️ **Implication:** Output files must be written to a different location

---

## Output Data Structure

### Base Location
```
/home/lmsmith/servers/analysis
```

### Directory Structure
```
servers/analysis/
├── Anand_Karthik/
├── Anthony_Renard/
├── Axel_Bisi/
├── Carl_Petersen/
├── Jules_Lebert/
├── Lana_Smith/
│   ├── MS122/
│   │   ├── analysis/              # Directory
│   │   ├── ch0/                   # Channel 0 data
│   │   ├── ch1/                   # Channel 1 data
│   │   ├── fiji_intensity/        # Directory
│   │   ├── MS122.xml              # XML file
│   │   └── registration/          # Registration results
│   └── MS181/
│       ├── analysis/
│       ├── ch0/
│       ├── ch1/
│       ├── fiji_intensity/
│       ├── MS181.xml
│       └── registration/
├── Marianne_Nkosi/
├── Mauro_Pulin/
└── ...
```

### Naming Conventions

**User Output Folders:**
- Format: `<FirstName>_<LastName>`
- Examples: `Lana_Smith`, `Carl_Petersen`, `Mauro_Pulin`

**Brain Output Folders:**
- Named after brain identifier (matches input)
- Example: `Lana_Smith/MS122/`

**Output Contents:**
- `analysis/` - Analysis results
- `ch0/`, `ch1/`, etc. - Per-channel data
- `fiji_intensity/` - Fiji intensity measurements
- `<brain_id>.xml` - BigStitcher XML file
- `registration/` - Brain registration results from brainreg

### SSH Access (To Be Determined)

**Current Status:** SSH path for output directory not yet confirmed.

**Likely format:**
```bash
# Needs verification
lmsmith@haas056.rcp.epfl.ch:/mnt/lsens-analysis/<Full_Name>/<brain_id>/
```

To find the SSH path, run on the cluster:
```bash
# From the analysis directory
cd /home/lmsmith/servers/analysis/Lana_Smith/MS122
readlink -f .
# This should show the actual mounted path
```

---

## Pipeline Integration

### Current Implementation

The pipeline uses SSH paths for:
1. **Input:** Reading `.czi` files via rsync
2. **Output:** Publishing XML files and registration results back via SSH

### File Publishing

**XML Files:**
- `<brain_id>_unregistered.xml` - Published after initial dataset creation
- `<brain_id>_registered.xml` - Published after stitching/registration

**Registration Results:**
- Published to subdirectories named with parameter combinations
- Format: `<brain_id>_bending_energy_weight<value>_grid_spacing<value>_smoothing_sigma_floating<value>/`

### Example Workflow

```bash
# Input CZI file (via SSH)
lmsmith@haas056.rcp.epfl.ch:/mnt/lsens-data/MS181/Anatomy/MS181.czi

# Outputs published back to same directory:
# - MS181_unregistered.xml
# - MS181_registered.xml

# Registration results published to output directory (TBD):
# Lana_Smith/MS181/registration/MS181_bending_energy_weight0.3_grid_spacing4_smoothing_sigma_floating-1/
# Lana_Smith/MS181/registration/MS181_bending_energy_weight0.8_grid_spacing4_smoothing_sigma_floating-1/
```

---

## Notes

1. **Transfer Speed:** Always use SSH paths (`lmsmith@haas056.rcp.epfl.ch:...`) for pipeline input to ensure fast transfer speeds.

2. **Storage Separation:** Input data and output data are stored in separate directory trees due to permission constraints.

3. **Naming Consistency:** Brain identifiers (e.g., `MS181`) are used consistently across input filenames, output folder names, and XML filenames.

4. **Multiple Users:** The output directory structure supports multiple lab members with their own subdirectories.

5. **Parameter Sweeps:** When running brainreg with multiple parameter combinations, each combination gets its own output subdirectory.

---

## TODO

- [ ] Determine correct SSH path for output directory (`/home/lmsmith/servers/analysis`)
- [ ] Confirm whether output directories need write/modify permissions
- [ ] Document expected output file sizes for storage planning
- [ ] Set up automated cleanup of intermediate files if needed
