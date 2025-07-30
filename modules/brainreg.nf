#!/usr/bin/env nextflow

process brainregEnvInstall {
    container 'python:3.11'
    
    output:
    path "brainreg_env"
    
    script:
    """
    # Install to a specific directory
    pip install --target brainreg_env brainreg==1.0.13 tables==3.10.2
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

process brainregRunRegistration {
    container 'python:3.11'
    
    input:
    path brainreg_env
    path atlas_cache
    tuple path(fused_image), val(image_name), val(voxel_x), val(voxel_y), val(voxel_z)
    val config
    
    // output:
    // path "brainreg_log.txt"
    
    script:
    params_brainreg = config.brainreg
    
    def orientation
    if (!config.bigstitcher.reorientation.reorient_to_asr) {
        orientation = config.bigstitcher.reorientation.raw_orientation.toLowerCase()
    } else {
        orientation = "asr"
    }


    """
    # Add the shared directory to Python path
    export PYTHONPATH=\${PWD}/${brainreg_env}:\${PYTHONPATH:-}
    # Add the bin directory to PATH (where executables are installed)
    export PATH=\${PWD}/${brainreg_env}/bin:\${PATH}

    # Use pre-downloaded atlas cache
    export BRAINGLOBE_HOME=\${PWD}/${atlas_cache}
    export XDG_CONFIG_HOME=\${PWD}/${atlas_cache}
    export HOME=\${PWD}
    
    echo ${params_brainreg.atlas}

    # Run brainreg with all parameters
    brainreg \\
        --atlas ${params_brainreg.atlas} \\
        --backend ${params_brainreg.backend} \\
        --affine-n-steps ${params_brainreg.affine_n_steps} \\
        --affine-use-n-steps ${params_brainreg.affine_use_n_steps} \\
        --freeform-n-steps ${params_brainreg.freeform_n_steps} \\
        --freeform-use-n-steps ${params_brainreg.freeform_use_n_steps} \\
        --bending-energy-weight ${params_brainreg.bending_energy_weight} \\
        --grid-spacing ${params_brainreg.grid_spacing} \\
        --smoothing-sigma-reference ${params_brainreg.smoothing_sigma_reference} \\
        --smoothing-sigma-floating ${params_brainreg.smoothing_sigma_floating} \\
        --histogram-n-bins-floating ${params_brainreg.histogram_n_bins_floating} \\
        --histogram-n-bins-reference ${params_brainreg.histogram_n_bins_reference} \\
        -v ${voxel_z} ${voxel_y} ${voxel_x} \\
        --n-free-cpus ${params_brainreg.n_free_cpus} \\
        ${params_brainreg.debug ? '--debug' : ''} \\
        --orientation ${orientation} \\
        ${params_brainreg.save_original_orientation ? '--save-original-orientation' : ''} \\
        --brain_geometry ${params_brainreg.brain_geometry} \\
        ${params_brainreg.sort_input_file ? '--sort-input-file' : ''} \\
        --pre-processing ${params_brainreg.pre_processing} \\
        ${fused_image} . 
    
    echo "Brainreg processing completed successfully"
    """
}

process downloadAtlas {
    container 'python:3.11'
    publishDir "${workflow.projectDir}/atlas_cache", mode: 'copy'
    
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
