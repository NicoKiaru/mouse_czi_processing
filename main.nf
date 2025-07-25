#!/usr/bin/env nextflow
include { setupFiji; useCachedFiji } from './modules/fiji'
include { stageFilesRSync } from './modules/upload_data'
include { makeCziDatasetForBigstitcher; alignChannelsWithBigstitcher } from './modules/bigstitcher'

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
    
    stageFilesRSync(images)

    // Makes a bigstitcher xml compatible file from the czi file
    makeCziDatasetForBigstitcher(stageFilesRSync.out, fiji_path)

    alignChannelsWithBigstitcher(makeCziDatasetForBigstitcher.out, fiji_path, params.bigstitcher)

    //results.view { "Completed: $it" }
}