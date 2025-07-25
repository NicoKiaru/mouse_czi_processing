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
    # PARAMS="xml_file=\"\${FULL_XML_PATH}\",pairwise_shifts_downsamples_x=${psd.x},pairwise_shifts_downsamples_y=${psd.y},pairwise_shifts_downsamples_z=${psd.z},filter_min_r=${ca.filter_min_r}"

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