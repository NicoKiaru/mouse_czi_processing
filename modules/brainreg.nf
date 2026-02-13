#!/usr/bin/env nextflow

process brainregEnvInstall {
    container 'python:3.11'
    cache 'lenient'
    storeDir params.env_cache_dir
    
    output:
    path "brainreg_env"
    
    script:
    """
    # Ensure pip is available
    python3 -m ensurepip --upgrade
    python3 -m pip install --target brainreg_env brainreg==1.0.13 tables==3.10.2 imagecodecs
    echo "Installation complete"
    """
}

process brainregTestEnv {
    container 'python:3.11'
   
    input:
    path brainreg_env
   
    output:
    path "results.txt"
   
    script:
    """
    # Add the shared directory to Python path (handle unset PYTHONPATH)
    export PYTHONPATH=\${PWD}/${brainreg_env}:\${PYTHONPATH:-}

    python -c "
    import sys
    import brainreg
    import tables

    print('✓ Using shared installation!')
    print('Python version:', sys.version.split()[0])
    print('Brainreg version:', getattr(brainreg, '__version__', 'unknown'))
    print('Tables version:', getattr(tables, '__version__', 'unknown'))
    " > results.txt
    """
}

process organizeChannelsForBrainreg {
    tag "organize ${base_name}"
    // publishDir "${params.outdir}/brainreg_ready", mode: 'copy'
    
    input:
    tuple val(base_name), path(channel_files)
    val registration_channel
    
    output:
    tuple path("primary/*.tiff"), path("additional_channels.txt"), val(base_name), emit: organized_channels

    script:
    """
    # Sort channel files to ensure consistent ordering
    SORTED_FILES=\$(ls ${channel_files} | sort -V)
    echo "Found channels:"
    echo "\${SORTED_FILES}"

    # Count channels
    CHANNEL_COUNT=\$(echo "\${SORTED_FILES}" | wc -l)
    echo "Total channels: \${CHANNEL_COUNT}"

    # Extract the primary channel (0-indexed)
    PRIMARY_CHANNEL=\$(echo "\${SORTED_FILES}" | sed -n "\$((${registration_channel} + 1))p")
    echo "Primary channel for registration: \${PRIMARY_CHANNEL}"

    # Copy primary channel to subdirectory, preserving its original name
    mkdir -p primary
    cp "\${PRIMARY_CHANNEL}" primary/

    # Create list of additional channels (all except primary)
    > additional_channels.txt
    CHANNEL_INDEX=0
    for CHANNEL in \${SORTED_FILES}; do
        if [ \${CHANNEL_INDEX} -ne ${registration_channel} ]; then
            # Write full path to the additional channels file
            echo "\$(pwd)/\${CHANNEL}" >> additional_channels.txt
        fi
        CHANNEL_INDEX=\$((CHANNEL_INDEX + 1))
    done

    echo "Additional channels:"
    cat additional_channels.txt
    """
}
process brainregRunRegistration {
    container 'python:3.11'
    // Updated tag to include parameter combination info
    tag "brainreg_${image_name}_bending${param_combo.bending_energy_weight}_grid${param_combo.grid_spacing}_sigma${param_combo.smoothing_sigma_floating}"
    
    // Updated publishDir to organize outputs by parameter combination
    // publishDir "${params.outdir}/brainreg_output/${image_name}_bending${param_combo.bending_energy_weight}_grid${param_combo.grid_spacing}_sigma${param_combo.smoothing_sigma_floating}", mode: 'copy'
    
    input:
    path brainreg_env
    path atlas_cache
    tuple path(primary_channel), path(additional_channels_file), val(image_name), val(voxel_x), val(voxel_y), val(voxel_z), val(param_combo)
    val config
    
    output:
    path "brainreg_output/*", emit: registered_brain
    path "brainreg_log.txt", emit: log
    tuple val(image_name), val(param_combo), path("brainreg_output/*"), emit: named_results

    script:
    params_brainreg = config.brainreg
    
    def orientation
    if (!config.bigstitcher.reorientation.reorient_to_asr) {
        orientation = config.bigstitcher.reorientation.raw_orientation.toLowerCase()
    } else {
        orientation = "asr"
    }
    
    // Read additional channels from file
    def additional_channels_args = ""
    if (additional_channels_file.name != "NO_FILE") {
        additional_channels_args = "--additional \$(cat ${additional_channels_file} | tr '\\n' ' ')"
    }
    
    """
    # Add the shared directory to Python path
    export PYTHONPATH=\${PWD}/${brainreg_env}:\${PYTHONPATH:-}
    export PATH=\${PWD}/${brainreg_env}/bin:\${PATH}

    # Use pre-downloaded atlas cache
    export BRAINGLOBE_HOME=\${PWD}/${atlas_cache}
    export XDG_CONFIG_HOME=\${PWD}/${atlas_cache}
    export HOME=\${PWD}
    
    echo "Processing image: ${image_name}"
    echo "Parameter combination:"
    echo "  bending_energy_weight: ${param_combo.bending_energy_weight}"
    echo "  grid_spacing: ${param_combo.grid_spacing}"
    echo "  smoothing_sigma_floating: ${param_combo.smoothing_sigma_floating}"
    echo "Primary channel: ${primary_channel}"
    echo "Additional channels:"
    if [ -f "${additional_channels_file}" ]; then
        cat "${additional_channels_file}"
    fi
    
    # Create output directory
    mkdir -p brainreg_output
    
    # Build the brainreg command
    BRAINREG_CMD="brainreg \\
        ${primary_channel} \\
        brainreg_output \\
        --atlas ${params_brainreg.atlas} \\
        --backend ${params_brainreg.backend} \\
        --affine-n-steps ${params_brainreg.affine_n_steps} \\
        --affine-use-n-steps ${params_brainreg.affine_use_n_steps} \\
        --freeform-n-steps ${params_brainreg.freeform_n_steps} \\
        --freeform-use-n-steps ${params_brainreg.freeform_use_n_steps} \\
        --bending-energy-weight ${param_combo.bending_energy_weight} \\
        --grid-spacing ${param_combo.grid_spacing} \\
        --smoothing-sigma-reference ${params_brainreg.smoothing_sigma_reference} \\
        --smoothing-sigma-floating ${param_combo.smoothing_sigma_floating} \\
        --histogram-n-bins-floating ${params_brainreg.histogram_n_bins_floating} \\
        --histogram-n-bins-reference ${params_brainreg.histogram_n_bins_reference} \\
        -v ${voxel_z} ${voxel_y} ${voxel_x} \\
        --n-free-cpus ${params_brainreg.n_free_cpus} \\
        ${params_brainreg.debug ? '--debug' : ''} \\
        --orientation ${orientation} \\
        ${params_brainreg.save_original_orientation ? '--save-original-orientation' : ''} \\
        --brain_geometry ${params_brainreg.brain_geometry} \\
        ${params_brainreg.sort_input_file ? '--sort-input-file' : ''} \\
        --pre-processing ${params_brainreg.pre_processing}"
    
    # Add additional channels if they exist
    if [ -f "${additional_channels_file}" ] && [ -s "${additional_channels_file}" ]; then
        echo "Adding additional channels to brainreg command"
        BRAINREG_CMD="\${BRAINREG_CMD} ${additional_channels_args}"
    fi
    
    echo "Full brainreg command:"
    echo "\${BRAINREG_CMD}"
    
    # Run brainreg
    eval "\${BRAINREG_CMD}" 2>&1 | tee brainreg_log.txt
    
    echo "Brainreg processing completed for parameter combination:"
    echo "  bending_energy_weight: ${param_combo.bending_energy_weight}"
    echo "  grid_spacing: ${param_combo.grid_spacing}" 
    echo "  smoothing_sigma_floating: ${param_combo.smoothing_sigma_floating}"
    ls -la brainreg_output/
    """
}

process downloadAtlas {
    container 'python:3.11'
    storeDir params.atlas_cache_dir
    
    input:
    path brainreg_env
    val atlas_name
    
    output:
    path "brainglobe_cache", emit: atlas_cache
    
    script:
    """
    export PYTHONPATH=\${PWD}/${brainreg_env}:\${PYTHONPATH:-}
    export PATH=\${PWD}/${brainreg_env}/bin:\${PATH}
    
    # Create cache directory
    mkdir -p brainglobe_cache
    export BRAINGLOBE_HOME=\${PWD}/brainglobe_cache
    export XDG_CONFIG_HOME=\${PWD}/brainglobe_cache
    export HOME=\${PWD}
    
    # Download atlas
    python -c "
from brainglobe_atlasapi.bg_atlas import BrainGlobeAtlas
atlas = BrainGlobeAtlas('${atlas_name}')
print(f'Atlas ${atlas_name} downloaded and cached successfully')
"
    """
}
