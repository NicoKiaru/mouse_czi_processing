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

process copyResultsToImageFolder {
    tag "${key}_${combo.collect { k, v -> "${k}${v}" }.join('_')}" // Optional: for logging/identification
    
    input:
    tuple val(key), val(ssh_path), val(combo), path(output_files), val(original_path_str)
    
    // No Output
   
    script:
    // Parse SSH path: user@host:/path/to/file
    def parts = original_path_str.split(':')
    def sshHost = parts[0]  // user@host
    def remotePath = parts[1]  // /path/to/file
    def remoteDir = remotePath.substring(0, remotePath.lastIndexOf('/'))
    def basename = remotePath.split('/')[-1].replaceAll(/\.[^.]+$/, '')
    
    // Construct the target subfolder name from the parameters
    def paramsString = combo.collect { k, v -> "${k}${v}" }.join('_')
    def targetDir = "${remoteDir}/${basename}_${paramsString}"
    
    """
    echo "Create the target directory via SSH: ${sshHost}:${targetDir}"
    ssh ${sshHost} "mkdir -p ${targetDir}"
    
    # Copy each file individually with SMB-friendly flags to remote server
    for file in ${output_files}; do
        rsync -rltvL --progress --inplace --no-perms --no-owner --no-group --no-times --modify-window=1 "\$file" "${sshHost}:${targetDir}/"
    done
    
    # Copy the contents of the niftyreg directory
    niftyreg_dir=\$(echo ${output_files} | grep -o 'niftyreg')
    if [ -n "\$niftyreg_dir" ]; then
        rsync -rltvL --progress --inplace --no-perms --no-owner --no-group --no-times --modify-window=1 "\$niftyreg_dir"/ "${sshHost}:${targetDir}/"
    fi
    
    echo "Successfully copied results to: ${sshHost}:${targetDir}"
    """
}

process stageFilesRSyncSSH {
    tag "stageRSyncSSH_${ssh_path.split('/')[-1]}"

    // Disable Nextflow's automatic staging
    stageInMode 'copy'
    
    input:
    val(ssh_path)
    
    output:
    path "${ssh_path.split('/')[-1]}", emit: staged_file
    
    script:
    def filename = ssh_path.split('/')[-1]
    """
    rsync -avz --progress "${ssh_path}" ./
    
    if [ ! -f "${filename}" ]; then
        echo "ERROR: File transfer failed"
        exit 1
    fi
    """
}