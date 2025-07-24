#!/usr/bin/env nextflow
include { setupFiji; useCachedFiji } from './modules/fiji'

process processImages {
    tag "processing ${image.baseName}"
    
    input:
    path image
    env FIJI_PATH
    
    output:
    path "processed_${image}"
    
    script:
    """
    # Echo the file paths for testing
    echo "Fiji installation path: \${FIJI_PATH}"
    echo "Processing image: ${image}"
    echo "Image basename: ${image.baseName}"
    
    
    # let's try to start Fiji
    # Run Fiji with the macro
    \${FIJI_PATH}/Fiji.app/ImageJ-linux64 --headless --console
    
    # Create a dummy output file for now
    touch "processed_${image}"

    """
}

workflow {
    // Check if Fiji already exists, otherwise set it up
    if (file("${params.fiji_cache_dir}/fiji_installation").exists()) {
        fiji_path = Channel.value("${params.fiji_cache_dir}/fiji_installation")
        log.info "Using cached Fiji installation at: ${params.fiji_cache_dir}/fiji_installation"
    } else {
        log.info "Setting up new Fiji installation..."
        fiji_path = setupFiji()
    }
    
    // Handle input files - properly split comma-separated input
    if (params.input) {
        // Split by comma, trim whitespace, and create channel
        input_files = params.input.split(',').collect { it.trim() }
        images = Channel.fromList(input_files).map { file(it) }
    } else {
        // Default: look for CZI files in current directory
        images = Channel.fromPath("*.{czi,tif,tiff}", checkIfExists: false)
    }
    
    // Debug: show what files were found BEFORE processing
    images = images.view { "Found input file: $it" }
    
    // Process images - combine each image with the fiji path as environment variable
    results = processImages(images, fiji_path)
    results.view { "Completed: $it" }
}