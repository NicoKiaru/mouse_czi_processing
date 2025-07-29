#!/usr/bin/env nextflow
include { setupFiji; useCachedFiji } from './modules/fiji'

include { stageFilesRSync } from './modules/upload_data'

include { 
    makeCziDatasetForBigstitcher; 
    alignChannelsWithBigstitcher; 
    alignTilesWithBigstitcher; 
    icpRefinementWithBigstitcher; 
    reorientToASRWithBigstitcher; 
    fuseBigStitcherDataset;
    getVoxelSizes; } from './modules/bigstitcher'

include { brainregEnvInstall; 
          brainregTestEnv;
          brainregRunRegistration;
          downloadAtlas } from './modules/brainreg'

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

    // Channel alignment
    channel_aligned = alignChannelsWithBigstitcher(makeCziDatasetForBigstitcher.out, fiji_path, params.bigstitcher)

    // Tile alignment 
    tile_aligned = alignTilesWithBigstitcher(channel_aligned.aligned_xml, fiji_path, params.bigstitcher)

    // ICP refinement
    icp_refined = icpRefinementWithBigstitcher(tile_aligned.tile_aligned_xml, fiji_path, params.bigstitcher)

    // ASR Reorientation
    reoriented_to_asr = reorientToASRWithBigstitcher(icp_refined.icp_refined_xml, fiji_path, params.bigstitcher)

    fused_image = fuseBigStitcherDataset(reoriented_to_asr.asr_xml, fiji_path, params.bigstitcher)

    // Get voxel sizes
    voxel_results = getVoxelSizes(fused_image.fused_image, fiji_path)

    voxel_results.voxel_sizes.view { image_name, x, y, z ->
        "Image: ${image_name}, Voxel sizes: X=${x}, Y=${y}, Z=${z}"
    }

    brainreg_install = brainregEnvInstall()

    //brainregTestEnv(brainregEnvInstall.out).view { "Test results: ${it.text}" }

    // Combine the fused image with voxel sizes
    combined_data = fused_image.fused_image.combine(voxel_results.voxel_sizes)

    atlas_cache = downloadAtlas(brainreg_install, params.brainreg.atlas)

    brainregRunRegistration(brainreg_install,
                            atlas_cache,
                            combined_data,
                            params)
}