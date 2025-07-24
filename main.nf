#!/usr/bin/env nextflow

include { setupFiji; useCachedFiji } from './modules/fiji'

/*process processImages {
    input:
    path fiji_installation
    path image
    
    output:
    path "processed_${image}"
    
    script:
    """
    # Use the shared Fiji installation
     ${fiji_installation}/ImageJ-linux64 --ij2 --headless --console \
         --run "your_script.ijm" --args "${image}"
    """
}*/

process processImages {
    input:
    path fiji_installation
    path image
    
    output:
    path "processed_${image}"
    
    script:
    """
    # Echo the file paths for testing
    echo "Fiji installation path: ${fiji_installation}"
    echo "Image file: ${image}"
    
    # Create a dummy output file for now
    touch "processed_${image}"
    """
}

workflow {
    // Check if Fiji already exists, otherwise set it up
    if (file("${params.fiji_cache_dir}/fiji_installation").exists()) {
        fiji_ready = Channel.of("${params.fiji_cache_dir}/fiji_installation")
    } else {
        fiji_ready = setupFiji()
    }
    
    // Process your images
    images = Channel.fromPath("*.{czi,tif}")
    results = processImages(fiji_ready, images)
}