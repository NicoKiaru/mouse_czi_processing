process stageFiles {
    tag "stage_${file(input_file).name}"
    
    input:
    path input_file
    
    output:
    path "${file(input_file).name}", emit: staged_file
    
    script:
    """
    # Nextflow automatically stages the input file to the work directory
    # We can use rsync for a robust copy with verification
    
    echo "Staging file: ${input_file}"
    echo "Current directory: \$(pwd)"
    echo "File size: \$(stat -c%s "${input_file}" 2>/dev/null || stat -f%z "${input_file}" 2>/dev/null) bytes"
    
    # The file is already staged by Nextflow, but we can verify it
    if [ -f "${file(input_file).name}" ]; then
        echo "File successfully staged: ${file(input_file).name}"
        
        # Optional: Calculate checksum for verification
        if command -v md5sum &> /dev/null; then
            MD5_CHECKSUM=\$(md5sum "${file(input_file).name}" | cut -d' ' -f1)
            echo "MD5 checksum: \$MD5_CHECKSUM"
        fi
    else
        echo "ERROR: Staged file not found!"
        exit 1
    fi
    """
}

process stageFilesRSync {
    tag "stageRSync_${file(input_file).name}"
    
    // Disable Nextflow's automatic staging
    stageInMode 'copy'
    
    input:
    path input_file
    
    output:
    path "${file(input_file).name}", emit: staged_file
    
    script:
    """
    # Use rsync for robust file transfer with verification
    echo "Staging file with rsync: ${input_file}"
    echo "Source path: ${input_file}"
    echo "Target: \$(pwd)/${file(input_file).name}"
    
    # Set rsync options for robust transfer
    RSYNC_OPTS="--archive"           # Preserve permissions, timestamps, etc.
    # RSYNC_OPTS="\$RSYNC_OPTS --checksum"      # Verify with checksums, not just size/time
    RSYNC_OPTS="\$RSYNC_OPTS --partial"       # Keep partial transfers for resume
    RSYNC_OPTS="\$RSYNC_OPTS --progress"      # Show progress
    RSYNC_OPTS="\$RSYNC_OPTS --compress"      # Compress during transfer (good for CZI)
    
    # Number of retry attempts
    MAX_RETRIES=3
    RETRY_COUNT=0
    
    # Transfer with retry logic
    while [ \$RETRY_COUNT -lt \$MAX_RETRIES ]; do
        echo "Transfer attempt \$((RETRY_COUNT + 1)) of \$MAX_RETRIES"
        
        if rsync \${RSYNC_OPTS} "${input_file}" "./"; then
            echo "Successfully transferred via rsync"
            break
        else
            RETRY_COUNT=\$((RETRY_COUNT + 1))
            if [ \$RETRY_COUNT -lt \$MAX_RETRIES ]; then
                echo "Transfer failed, retrying in 5 seconds..."
                sleep 5
            else
                echo "ERROR: Failed to transfer after \$MAX_RETRIES attempts"
                exit 1
            fi
        fi
    done
    
    # Verify the transferred file
    if [ -f "${file(input_file).name}" ]; then
        # Get file sizes for verification
        ORIGINAL_SIZE=\$(stat -c%s "${input_file}" 2>/dev/null || stat -f%z "${input_file}" 2>/dev/null)
        TRANSFERRED_SIZE=\$(stat -c%s "${file(input_file).name}" 2>/dev/null || stat -f%z "${file(input_file).name}" 2>/dev/null)
        
        echo "Original size: \$ORIGINAL_SIZE bytes"
        echo "Transferred size: \$TRANSFERRED_SIZE bytes"
        
        if [ "\$ORIGINAL_SIZE" = "\$TRANSFERRED_SIZE" ]; then
            echo "File size verification: PASSED"
        else
            echo "ERROR: File size mismatch!"
            exit 1
        fi
        
        # Calculate checksums for extra verification
        # if command -v md5sum &> /dev/null; then
        #    echo "Calculating MD5 checksums..."
        #    ORIGINAL_MD5=\$(md5sum "${input_file}" | cut -d' ' -f1)
        #    TRANSFERRED_MD5=\$(md5sum "${file(input_file).name}" | cut -d' ' -f1)
        #    
        #    echo "Original MD5: \$ORIGINAL_MD5"
        #    echo "Transferred MD5: \$TRANSFERRED_MD5"
        #    
        #    if [ "\$ORIGINAL_MD5" = "\$TRANSFERRED_MD5" ]; then
        #        echo "MD5 verification: PASSED"
        #    else
        #        echo "ERROR: MD5 checksum mismatch!"
        #        exit 1
        #    fi
        # fi
    else
        echo "ERROR: Transferred file not found!"
        exit 1
    fi
    
    echo "File staging completed successfully"
    """
}