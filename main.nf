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
          downloadAtlas;
          organizeChannelsForBrainreg } from './modules/brainreg'

// Helper function to ensure parameter is a list
def ensureList(param) {
    return param instanceof List ? param : [param]
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
    
    stageFilesRSync(images)

    // Makes a bigstitcher xml compatible file from the czi file
    makeCziDatasetForBigstitcher(stageFilesRSync.out, fiji_path)

    // Channel alignment
    channel_aligned = alignChannelsWithBigstitcher(makeCziDatasetForBigstitcher.out, fiji_path, params.bigstitcher)

    // Tile alignment 
    tile_aligned = alignTilesWithBigstitcher(channel_aligned.aligned_xml, fiji_path, params.bigstitcher)

    // ICP refinement
    icp_refined = icpRefinementWithBigstitcher(tile_aligned.tile_aligned_xml, fiji_path, params.bigstitcher)

    def xml_out

    // Optional ASR Reorientation
    if (params.bigstitcher.reorientation.reorient_to_asr) {
        reoriented_to_asr = reorientToASRWithBigstitcher(icp_refined.icp_refined_xml, fiji_path, params.bigstitcher)
        xml_out = reoriented_to_asr.asr_xml
    } else {
        xml_out = icp_refined.icp_refined_xml
    }


    // Fuse image - always splits by channel
    fused_images = fuseBigStitcherDataset(xml_out, fiji_path, params.bigstitcher)
    
    // Get voxel sizes from the first channel file
    first_channel = fused_images.fused_images
        .flatten()
        .first()
    
    voxel_results = getVoxelSizes(first_channel, fiji_path)
    
    // Organize channels for brainreg
    organized_channels = organizeChannelsForBrainreg(
        fused_images.named_fused_images,
        params.brainreg.channel_used_for_registration
    )
    
    // Combine with voxel sizes for brainreg
    brainreg_input = organized_channels.organized_channels
        .combine(voxel_results.voxel_sizes.map { name, x, y, z -> tuple(x, y, z) })
    
    // View what will be processed

    /*brainreg_input.view { primary, additional, name, x, y, z -> 
        "Ready for brainreg: ${name} using primary channel with voxel sizes: X=${x}μm, Y=${y}μm, Z=${z}μm"
    }*/

    // CREATE PARAMETER SWEEP COMBINATIONS using Nextflow channels
    bending_energy_ch = Channel.fromList(ensureList(params.brainreg.bending_energy_weight))
    grid_spacing_ch = Channel.fromList(ensureList(params.brainreg.grid_spacing))
    smoothing_sigma_ch = Channel.fromList(ensureList(params.brainreg.smoothing_sigma_floating))
    
    // Combine all parameter channels to create all combinations NOTE: it's a nextflow channel, not an image channel!
    param_combinations = bending_energy_ch
        .combine(grid_spacing_ch)
        .combine(smoothing_sigma_ch)
        .map { bending, grid, sigma -> 
            [
                bending_energy_weight: bending,
                grid_spacing: grid,
                smoothing_sigma_floating: sigma
            ]
        }
    
    // Log the parameter combinations that will be tested
    param_combinations.view { combo ->
        "Parameter combination: bending_energy_weight=${combo.bending_energy_weight}, grid_spacing=${combo.grid_spacing}, smoothing_sigma_floating=${combo.smoothing_sigma_floating}"
    }
    
    // Cross brainreg input with parameter combinations
    brainreg_sweep_input = brainreg_input.combine(param_combinations)

    brainreg_install = brainregEnvInstall()
    atlas_cache = downloadAtlas(brainreg_install, params.brainreg.atlas)
    
    // Run brainreg with primary and additional channels
    brainregRunRegistration(brainreg_install,
                           atlas_cache,
                           brainreg_sweep_input,
                           params)

}