import argparse
from pathlib import Path
from iohub.ngff import open_ome_zarr
from tqdm.auto import tqdm
import numpy as np
import tifffile
from skimage.transform import rescale
import gc


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert a multi-page TIFF to OME-Zarr format.")
    parser.add_argument("-i", "--input", type=Path, required=True, help="Path to the input TIFF file.")
    parser.add_argument("-o", "--output", type=Path, required=True, help="Output .zarr path.")
    parser.add_argument("-l", "--levels", type=int, default=6, help="Number of resolution levels in the pyramid.")
    parser.add_argument("--channel-name", type=str, default="ch1", help="Output channel name.")
    parser.add_argument("--proper-downsample", action="store_true", default=False,
                        help="Use antialiasing filter for downsampling. Defaults to False.")
    args = parser.parse_args()

    assert args.output.suffix == ".zarr", "Output path must have .zarr suffix"
    assert args.input.is_file(), f"Input file does not exist: {args.input}"

    args.output.parent.mkdir(exist_ok=True, parents=True)

    print(f"Reading TIFF: {args.input}")
    stack = tifffile.imread(str(args.input))  # ZYX
    print(f"Loaded stack shape: {stack.shape}, dtype: {stack.dtype}")

    # Reshape to TCZYX (1 timepoint, 1 channel)
    stacked_img = stack[None, None]  # ZYX -> TCZYX
    del stack
    gc.collect()
    print(f"Reshaped to TCZYX: {stacked_img.shape}")

    with open_ome_zarr(
        str(args.output),
        layout="fov",
        mode="w-",
        channel_names=[args.channel_name],
    ) as dataset:
        for lv in tqdm(range(args.levels), total=args.levels, desc="Writing pyramid"):
            if lv == 0:
                rescaled_img = stacked_img
            else:
                if args.proper_downsample:
                    rescaled_img = rescale(
                        rescaled_img,
                        (1.0, 1.0, 1 / 2, 1 / 2, 1 / 2),
                        order=1,
                        preserve_range=True,
                        anti_aliasing=True,
                    ).astype(stacked_img.dtype)
                else:
                    rescaled_img = rescaled_img[..., ::2, ::2, ::2]

            img = dataset.create_zeros(
                name=str(lv),
                shape=rescaled_img.shape,
                dtype=rescaled_img.dtype,
                chunks=(1, 1, 256, 256, 256),
            )
            img[:] = rescaled_img

        dataset.print_tree()

    print(f"Saved OME-Zarr dataset to {args.output}")
