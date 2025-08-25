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
    getVoxelSizes;
    publishInitialXmlToSource;
    publishStitchedXmlToSource; } from './modules/bigstitcher'

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

    // Parameter validation
    if (!params.outdir) {
        error "ERROR: --outdir parameter is required but not provided. Please specify an output directory."
    }
    
    // Validate that outdir is a valid path (optional: create if it doesn't exist)
    try {
        def outdir = file(params.outdir)
        if (!outdir.exists()) {
            log.info "Creating output directory: ${params.outdir}"
            outdir.mkdirs()
        }
        if (!outdir.isDirectory()) {
            error "ERROR: --outdir '${params.outdir}' exists but is not a directory."
        }
        log.info "Output directory validated: ${params.outdir}"
    } catch (Exception e) {
        error "ERROR: Invalid output directory path '${params.outdir}': ${e.message}"
    }

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
        log.info "WARNING: no input file defined - running the pipeline will only install tools without using them"
    }

    // Debug: show what files were found BEFORE processing
    images = images.view { "Found input file: $it" }
    
    // Conditionally stage files based on profile or parameter
    def shouldStageFiles = workflow.profile.contains('slurm')
    
    if (shouldStageFiles) {
        log.info "File staging enabled (profile: ${workflow.profile}, stage_files: ${params.stage_files})"
        staged_files = stageFilesRSync(images)
    } else {
        log.info "File staging disabled - using files directly"
        staged_files = images
    }
    
    // Makes a bigstitcher xml compatible file from the czi file
    makeCziDatasetForBigstitcher(staged_files, fiji_path)

    xml_not_stitched_with_original_paths = makeCziDatasetForBigstitcher.out
        .merge(Channel.fromList(input_files)) { xml_file, original_path ->
            tuple(xml_file, file(original_path))
        }
    
    // Debug: Show the pairing
    xml_not_stitched_with_original_paths.view { xml_file, original_path ->
        "Will publish ${xml_file.name} alongside ${original_path}"
    }
    
    // Publish XML files to source locations
    publishInitialXmlToSource(xml_not_stitched_with_original_paths)

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

    // Pair XML files with their original input paths for publishing
    // original_paths = images_with_paths.map { original_path, file_obj -> original_path }
    
    // Channel.fromList(input_files)

    xml_with_original_paths = xml_out
        .merge(Channel.fromList(input_files)) { xml_file, original_path ->
            tuple(xml_file, file(original_path))
        }
    
    // Debug: Show the pairing
    xml_with_original_paths.view { xml_file, original_path ->
        "Will publish ${xml_file.name} alongside ${original_path}"
    }
    
    // Publish XML files to source locations
    publishStitchedXmlToSource(xml_with_original_paths)

    // Fuse image - always splits by channel
    fused_images = fuseBigStitcherDataset(xml_out, fiji_path, params.bigstitcher)
    
    // Process each image completely through the brainreg preparation pipeline
    image_processing = fused_images.named_fused_images
        .map { base_name, channel_files ->
            // Get first channel for voxel size detection
            def file_list = channel_files instanceof List ? channel_files : [channel_files]
            def sorted_files = file_list.sort { it.name }
            def first_channel = sorted_files[0]
            
            // Return tuple with all info needed for this image
            return tuple(base_name, channel_files, first_channel)
        }
    
    // Debug: Show what we're processing
    image_processing.view { base_name, channel_files, first_channel ->
        "Processing image: ${base_name} with ${channel_files.size()} channels, using ${first_channel.name} for voxel sizes"
    }
    
    // Get voxel sizes for each image
    voxel_results = getVoxelSizes(
        image_processing.map { base_name, channel_files, first_channel -> first_channel }, 
        fiji_path
    )
    
    // Organize channels for brainreg for each image
    organized_channels = organizeChannelsForBrainreg(
        image_processing.map { base_name, channel_files, first_channel -> tuple(base_name, channel_files) },
        params.brainreg.channel_used_for_registration
    )
    
    // Combine everything for brainreg input (same order guaranteed)
    brainreg_input = organized_channels.organized_channels
        .merge(voxel_results.voxel_sizes) { organized_tuple, voxel_tuple -> 
            def (primary, additional, base_name) = organized_tuple
            def (voxel_name, x, y, z) = voxel_tuple
            return tuple(primary, additional, base_name, x, y, z)
        }
    
    // Debug: View what will be processed
    brainreg_input.view { primary, additional, name, x, y, z -> 
        "Ready for brainreg: ${name} using primary channel with voxel sizes: X=${x}μm, Y=${y}μm, Z=${z}μm"
    }

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