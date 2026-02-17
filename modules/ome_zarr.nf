process omeZarrEnvInstall {
    container 'python:3.11'
    cache 'lenient'
    storeDir params.env_cache_dir

    output:
    path "ome_zarr_env"

    script:
    """
    python3 -m ensurepip --upgrade
    python3 -m pip install --target ome_zarr_env iohub tifffile scikit-image numpy tqdm imagecodecs
    echo "OME-Zarr environment installation complete"
    """
}

process convertTiffToOmeZarr {
    container 'python:3.11'
    tag "ome_zarr_${brain_key}"

    input:
    path ome_zarr_env
    tuple val(brain_key), path(ch1_tiff), val(zarr_output_path)

    output:
    tuple val(brain_key), path("ch1.ome.zarr"), val(zarr_output_path), emit: zarr_result

    script:
    """
    export PYTHONPATH=\${PWD}/${ome_zarr_env}:\${PYTHONPATH:-}

    # Copy conversion script to work directory
    cp ${projectDir}/bin/tiff_to_ome_zarr.py .

    echo "Converting ${ch1_tiff} to OME-Zarr"

    # Write zarr to local work directory (container can't write to /work/lsens)
    python3 tiff_to_ome_zarr.py \\
        --input "${ch1_tiff}" \\
        --output "ch1.ome.zarr" \\
        --channel-name ch1 \\
        --levels 6
    """
}

process publishOmeZarr {
    tag "publish ome_zarr ${brain_key}"

    input:
    tuple val(brain_key), path(zarr_dir), val(zarr_output_path)

    output:
    path "publish_log.txt", emit: log

    script:
    """
    echo "Publishing ${zarr_dir} to ${zarr_output_path}" | tee publish_log.txt

    # Create target parent directory
    mkdir -p \$(dirname "${zarr_output_path}")

    # Copy zarr directory to final location
    cp -r "${zarr_dir}" "${zarr_output_path}"

    echo "Successfully published OME-Zarr to ${zarr_output_path}" | tee -a publish_log.txt
    echo "Completed at: \$(date)" >> publish_log.txt
    """
}
