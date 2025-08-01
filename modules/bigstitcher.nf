process makeCziDatasetForBigstitcher {
    tag "make bigstitcher xml from czi ${image.baseName}"
    
    input:
    path image
    env FIJI_PATH
    
    output:
    path "${image.baseName}_bigstitcher.xml", emit: xml_file
    
    script:
    """
    # Copy the groovy script to the work directory
    cp ${projectDir}/bin/make_czi_dataset_for_bigstitcher.ijm .

    \${FIJI_PATH}/Fiji.app/ImageJ-linux64 --ij2 --headless --console \\
        --run make_czi_dataset_for_bigstitcher.ijm \\
        'czi_file="${image}",xml_out="${image.baseName}_bigstitcher.xml"'
    """
}

process alignChannelsWithBigstitcher {
    tag "align channels ${xml_file.baseName}"
    // publishDir "${params.outdir}/channel_alignment", mode: 'copy'
    
    input:
    path xml_file
    env FIJI_PATH
    val config
    
    output:
    path "${xml_file.baseName}_aligned.xml", emit: aligned_xml
    
    script:
    def ca = config.channel_alignment
    def psd = ca.pairwise_shifts_downsamples
    
    """
    # Copy the groovy script to the work directory
    cp ${projectDir}/bin/align_channels_with_bigstitcher.ijm .
    
    # Create a copy of the input XML with the aligned suffix for processing
    # BigStitcher modifies the XML in place, so we work on a copy
    cp "${xml_file}" "${xml_file.baseName}_aligned.xml"
    
    # Get the full path to the aligned XML file
    FULL_XML_PATH="\$(pwd)/${xml_file.baseName}_aligned.xml"
    echo "Full XML path: \${FULL_XML_PATH}"
    
    # Build the parameter string with proper quoting
    
    PARAMS="xml_file=\\\""\${FULL_XML_PATH}"\\\",pairwise_shifts_downsamples_x=${psd.x},pairwise_shifts_downsamples_y=${psd.y},pairwise_shifts_downsamples_z=${psd.z},filter_min_r=${ca.filter_min_r}"

    echo "Parameters: \${PARAMS}"

    # Run Fiji
    \${FIJI_PATH}/Fiji.app/ImageJ-linux64 --ij2 --headless --console \\
        --run align_channels_with_bigstitcher.ijm \\
        "\${PARAMS}"

    """
}

process alignTilesWithBigstitcher {
    tag "align tiles ${xml_file.baseName}"
    
    input:
    path xml_file
    env FIJI_PATH
    val config
    
    output:
    path "${xml_file.baseName}_tile_aligned.xml", emit: tile_aligned_xml
    
    script:
    def ta = config.tile_alignment
    def psd = ta.pairwise_shifts_downsamples
    
    """
    # Copy the tile alignment script to the work directory
    cp ${projectDir}/bin/align_tiles_with_bigstitcher.ijm .
    
    # Create a copy for tile alignment processing
    cp "${xml_file}" "${xml_file.baseName}_tile_aligned.xml"
    
    # Get the full path
    FULL_XML_PATH="\$(pwd)/${xml_file.baseName}_tile_aligned.xml"
    echo "Full XML path: \${FULL_XML_PATH}" >> tile_alignment_log.txt
    
    # Build the parameter string with proper quoting
    PARAMS="xml_file=\\\""\${FULL_XML_PATH}"\\\",use_channel=${ta.use_channel},pairwise_shifts_downsamples_x=${psd.x},pairwise_shifts_downsamples_y=${psd.y},pairwise_shifts_downsamples_z=${psd.z},filter_min_r=${ta.filter_min_r}"
    echo "Parameters: \${PARAMS}" >> tile_alignment_log.txt
    
    # Run Fiji with tile alignment script
    \${FIJI_PATH}/Fiji.app/ImageJ-linux64 --ij2 --headless --console \\
        --run align_tiles_with_bigstitcher.ijm \\
        "\${PARAMS}"
    """
}

process icpRefinementWithBigstitcher {
    tag "icp refinement ${xml_file.baseName}"
    // publishDir "${params.outdir}/icp_refinement", mode: 'copy'
    
    input:
    path xml_file
    env FIJI_PATH
    val config
    
    output:
    path "${xml_file.baseName}_icp_refined.xml", emit: icp_refined_xml
    
    script:
    def icp = config.icp_refinement
    
    """
    # Copy the ICP refinement script to the work directory
    cp ${projectDir}/bin/icp_refinement_with_bigstitcher.ijm .

    # Create a copy for ICP refinement processing
    cp "${xml_file}" "${xml_file.baseName}_icp_refined.xml"
    
    # Get the full path
    FULL_XML_PATH="\$(pwd)/${xml_file.baseName}_icp_refined.xml"
    
    # Build the parameter string with proper quoting
    PARAMS="xml_file=\\\""\${FULL_XML_PATH}"\\\",icp_refinement_type=\\\"${icp.icp_refinement_type}\\\",downsampling=\\\"${icp.downsampling}\\\",interest=\\\"${icp.interest}\\\",icp_max_error=\\\"${icp.icp_max_error}\\\""
    
    # Run Fiji with ICP refinement script
    \${FIJI_PATH}/Fiji.app/ImageJ-linux64 --ij2 --headless --console \\
        --run icp_refinement_with_bigstitcher.ijm \\
        "\${PARAMS}"
    """
}

process reorientToASRWithBigstitcher {
        tag "asr reorientation ${xml_file.baseName}"
    // publishDir "${params.outdir}/icp_refinement", mode: 'copy'
    
    input:
    path xml_file
    env FIJI_PATH
    val config
    
    output:
    path "${xml_file.baseName}_asr.xml", emit: asr_xml
    
    script:
    def reorient = config.reorientation
    
    """
    # Copy the ASR reorientation script to the work directory
    cp ${projectDir}/bin/reorient_to_asr_with_bigstitcher.groovy .
    # Create a copy for ASR reorientation processing
    cp "${xml_file}" "${xml_file.baseName}_asr.xml"
    
    # Get the full path
    FULL_XML_PATH="\$(pwd)/${xml_file.baseName}_asr.xml"
    
    # Build the parameter string with proper quoting
    PARAMS="xml_file=\\\""\${FULL_XML_PATH}"\\\",raw_orientation=\\\"${reorient.raw_orientation}\\\",reorient_to_asr=${reorient.reorient_to_asr}"
    
    # Run Fiji with ASR reorientation script
    \${FIJI_PATH}/Fiji.app/ImageJ-linux64 --ij2 --headless --console \\
        --run reorient_to_asr_with_bigstitcher.groovy \\
        "\${PARAMS}"
    """
}

process fuseBigStitcherDataset {
    tag "fuse dataset ${xml_file.baseName}"
    // publishDir "${params.outdir}/icp_refinement", mode: 'copy'
    
    input:
    path xml_file
    env FIJI_PATH
    val config
    
    output:
    path "${xml_file.baseName}.tiff", emit: fused_image

    script:
    def fuse = config.fusion_config
    
    """
    # Fuse dataset into an ome.tiff file
    cp ${projectDir}/bin/fuse_bigstitcher_dataset.groovy .
    
    OUTPUT_DIR_PATH="\$(pwd)/"
    
    # Build the parameter string with proper quoting
    PARAMS="xml_file=\\\""${xml_file}"\\\",fusion_method=\\\"${fuse.fusion_method}\\\",output_directory=\\\""\${OUTPUT_DIR_PATH}"\\\",downsample=\\\"${fuse.downsample}\\\""
    
    # Run Fiji with Fusion script
    \${FIJI_PATH}/Fiji.app/ImageJ-linux64 --ij2 --headless --console \\
        --run fuse_bigstitcher_dataset.groovy \\
        "\${PARAMS}"

    mv "${xml_file.baseName}.ome.tiff" "${xml_file.baseName}.tiff"    
    """

    
}



process getVoxelSizes {
    tag "get voxel sizes ${image_file.baseName}"
    
    input:
    path image_file
    env FIJI_PATH
    
    output:
    path "voxel_sizes.txt", emit: voxel_file
    tuple val("${image_file.baseName}"), env(VOXEL_X), env(VOXEL_Y), env(VOXEL_Z), emit: voxel_sizes
    
    script:
    """
    # Get Voxel Sizes Of The File
    cp ${projectDir}/bin/get_voxel_sizes_bigstitcher_dataset.groovy .
    
    OUTPUT_DIR_PATH="\$(pwd)/"
    
    # Build the parameter string with proper quoting
    PARAMS="image_file_path=\\\""${image_file}"\\\",output_directory=\\\""\${OUTPUT_DIR_PATH}"\\\""
    
    echo "Parameters: \${PARAMS}" >> get_voxel_sizes.txt
    
    # Run Fiji with voxel sizes script
    \${FIJI_PATH}/Fiji.app/ImageJ-linux64 --ij2 --headless --console \\
        --run get_voxel_sizes_bigstitcher_dataset.groovy \\
        "\${PARAMS}"
    
    # Verify the voxel_sizes.txt file was created and parse it
    if [ -f "voxel_sizes.txt" ]; then
        echo "Successfully produced voxel size text file" >> get_voxel_sizes.txt
        
        # Read and export the voxel sizes
        export VOXEL_X=\$(head -n 1 voxel_sizes.txt | tr -d '[:space:]')
        export VOXEL_Y=\$(head -n 2 voxel_sizes.txt | tail -n 1 | tr -d '[:space:]')
        export VOXEL_Z=\$(head -n 3 voxel_sizes.txt | tail -n 1 | tr -d '[:space:]')
        
        echo "Voxel sizes: X=\${VOXEL_X}, Y=\${VOXEL_Y}, Z=\${VOXEL_Z}" >> get_voxel_sizes.txt
    else
        echo "ERROR: Could not get voxel sizes - voxel_sizes.txt not found"
        echo "ERROR: Voxel sizes fetching failed at: \$(date)" >> get_voxel_sizes.txt
        exit 1
    fi
    """
}
