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

    
    echo "Fiji installation path: \${FIJI_PATH}"
    echo "Processing image: ${image}"
    echo "Image basename: ${image.baseName}"
    echo "Output XML will be: ${image.baseName}_bigstitcher.xml"
    
    # let's try to start Fiji

    \${FIJI_PATH}/Fiji.app/ImageJ-linux64 --ij2 --headless --console \\
        --run make_czi_dataset_for_bigstitcher.ijm \\
        'czi_file="${image}",xml_out="${image.baseName}_bigstitcher.xml"'
    
    # Verify the output was created
    if [ -f "${image.baseName}_bigstitcher.xml" ]; then
        echo "Successfully created XML file"
        ls -la "${image.baseName}_bigstitcher.xml"
    else
        echo "ERROR: XML file was not created"
        exit 1
    fi

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
    path "alignment_log.txt", emit: log
    
    script:
    def ca = config.channel_alignment
    def psd = ca.pairwise_shifts_downsamples
    
    """
    # Copy the groovy script to the work directory
    cp ${projectDir}/bin/align_channels_with_bigstitcher.ijm .
    
    echo "Fiji installation path: \${FIJI_PATH}"
    echo "Processing XML: ${xml_file}"
    echo "XML basename: ${xml_file.baseName}"
    echo "Pairwise shifts downsamples: x=${psd.x}, y=${psd.y}, z=${psd.z}"
    echo "Filter min r: ${ca.filter_min_r}"
    echo "Output XML will be: ${xml_file.baseName}_aligned.xml"
    
    # Log parameters for debugging
    echo "Channel alignment parameters:" > alignment_log.txt
    echo "  Pairwise shifts downsamples:" >> alignment_log.txt
    echo "    x: ${psd.x}" >> alignment_log.txt
    echo "    y: ${psd.y}" >> alignment_log.txt
    echo "    z: ${psd.z}" >> alignment_log.txt
    echo "  Filter min r: ${ca.filter_min_r}" >> alignment_log.txt
    echo "Starting channel alignment at: \$(date)" >> alignment_log.txt
    
    # Create a copy of the input XML with the aligned suffix for processing
    # BigStitcher modifies the XML in place, so we work on a copy
    cp "${xml_file}" "${xml_file.baseName}_aligned.xml"
    
    # Get the full path to the aligned XML file
    FULL_XML_PATH="\$(pwd)/${xml_file.baseName}_aligned.xml"
    echo "Full XML path: \${FULL_XML_PATH}"
    echo "Full XML path: \${FULL_XML_PATH}" >> alignment_log.txt
    
    # Build the parameter string with proper quoting
    
    PARAMS="xml_file=\\\""\${FULL_XML_PATH}"\\\",pairwise_shifts_downsamples_x=${psd.x},pairwise_shifts_downsamples_y=${psd.y},pairwise_shifts_downsamples_z=${psd.z},filter_min_r=${ca.filter_min_r}"

    echo "Parameters: \${PARAMS}"

    # Run Fiji
    \${FIJI_PATH}/Fiji.app/ImageJ-linux64 --ij2 --headless --console \\
        --run align_channels_with_bigstitcher.ijm \\
        "\${PARAMS}"

    # Verify the output was processed successfully
    if [ -f "${xml_file.baseName}_aligned.xml" ]; then
        echo "Successfully processed XML file for channel alignment"
        echo "Channel alignment completed at: \$(date)" >> alignment_log.txt
        ls -la "${xml_file.baseName}_aligned.xml" >> alignment_log.txt
    else
        echo "ERROR: Channel alignment failed - XML file was not created/modified"
        echo "ERROR: Channel alignment failed at: \$(date)" >> alignment_log.txt
        exit 1
    fi
    """
}

process alignTilesWithBigstitcher {
    tag "align tiles ${xml_file.baseName}"
    // publishDir "${params.outdir}/tile_alignment", mode: 'copy'
    
    input:
    path xml_file
    env FIJI_PATH
    val config
    
    output:
    path "${xml_file.baseName}_tile_aligned.xml", emit: tile_aligned_xml
    path "tile_alignment_log.txt", emit: log
    
    script:
    def ta = config.tile_alignment
    def psd = ta.pairwise_shifts_downsamples
    
    """
    # Copy the tile alignment script to the work directory
    cp ${projectDir}/bin/align_tiles_with_bigstitcher.ijm .
    
    echo "Processing XML for tile alignment: ${xml_file}"
    echo "Use channel: ${ta.use_channel}"
    echo "Pairwise shifts downsamples: x=${psd.x}, y=${psd.y}, z=${psd.z}"
    echo "Filter min r: ${ta.filter_min_r}"
    
    # Log parameters
    echo "Tile alignment parameters:" > tile_alignment_log.txt
    echo "  Use channel: ${ta.use_channel}" >> tile_alignment_log.txt
    echo "  Pairwise shifts downsamples:" >> tile_alignment_log.txt
    echo "    x: ${psd.x}" >> tile_alignment_log.txt
    echo "    y: ${psd.y}" >> tile_alignment_log.txt
    echo "    z: ${psd.z}" >> tile_alignment_log.txt
    echo "  Filter min r: ${ta.filter_min_r}" >> tile_alignment_log.txt
    echo "Starting tile alignment at: \$(date)" >> tile_alignment_log.txt
    
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
    
    # Verify success
    if [ -f "${xml_file.baseName}_tile_aligned.xml" ]; then
        echo "Successfully processed XML file for tile alignment"
        echo "Tile alignment completed at: \$(date)" >> tile_alignment_log.txt
    else
        echo "ERROR: Tile alignment failed"
        echo "ERROR: Tile alignment failed at: \$(date)" >> tile_alignment_log.txt
        exit 1
    fi
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
    path "icp_refinement_log.txt", emit: log
    
    script:
    def icp = config.icp_refinement
    
    """
    # Copy the ICP refinement script to the work directory
    cp ${projectDir}/bin/icp_refinement_with_bigstitcher.ijm .
    
    echo "Processing XML for ICP refinement: ${xml_file}"
    echo "ICP refinement type: ${icp.icp_refinement_type}"
    echo "Downsampling: ${icp.downsampling}"
    echo "Interest: ${icp.interest}"
    echo "ICP max error: ${icp.icp_max_error}"
    
    # Log parameters
    echo "ICP refinement parameters:" > icp_refinement_log.txt
    echo "  ICP refinement type: ${icp.icp_refinement_type}" >> icp_refinement_log.txt
    echo "  Downsampling: ${icp.downsampling}" >> icp_refinement_log.txt
    echo "  Interest: ${icp.interest}" >> icp_refinement_log.txt
    echo "  ICP max error: ${icp.icp_max_error}" >> icp_refinement_log.txt
    echo "Starting ICP refinement at: \$(date)" >> icp_refinement_log.txt
    
    # Create a copy for ICP refinement processing
    cp "${xml_file}" "${xml_file.baseName}_icp_refined.xml"
    
    # Get the full path
    FULL_XML_PATH="\$(pwd)/${xml_file.baseName}_icp_refined.xml"
    echo "Full XML path: \${FULL_XML_PATH}" >> icp_refinement_log.txt
    
    # Build the parameter string with proper quoting
    PARAMS="xml_file=\\\""\${FULL_XML_PATH}"\\\",icp_refinement_type=\\\"${icp.icp_refinement_type}\\\",downsampling=\\\"${icp.downsampling}\\\",interest=\\\"${icp.interest}\\\",icp_max_error=\\\"${icp.icp_max_error}\\\""
    echo "Parameters: \${PARAMS}" >> icp_refinement_log.txt
    
    # Run Fiji with ICP refinement script
    \${FIJI_PATH}/Fiji.app/ImageJ-linux64 --ij2 --headless --console \\
        --run icp_refinement_with_bigstitcher.ijm \\
        "\${PARAMS}"
    
    # Verify success
    if [ -f "${xml_file.baseName}_icp_refined.xml" ]; then
        echo "Successfully processed XML file for ICP refinement"
        echo "ICP refinement completed at: \$(date)" >> icp_refinement_log.txt
    else
        echo "ERROR: ICP refinement failed"
        echo "ERROR: ICP refinement failed at: \$(date)" >> icp_refinement_log.txt
        exit 1
    fi
    """
}