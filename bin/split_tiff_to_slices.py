"""Split a 3D TIFF into a directory of zero-padded 2D slice TIFFs.

brainreg dispatches to a slice-wise (multiprocessing) loader when its input is
a directory of 2D TIFFs, and to a single-threaded whole-volume loader when its
input is one 3D file. The slice-wise path is dramatically faster and lower
memory for the pre-registration downsample step on large mouse brains, so we
pre-split before handing channels to brainreg.

Streams page-by-page via tifffile so peak memory stays at one slice.
"""
import argparse
import os
import sys

import tifffile


def main():
    parser = argparse.ArgumentParser(description="Split a 3D TIFF into a directory of 2D slice TIFFs.")
    parser.add_argument("src", help="Source 3D TIFF file")
    parser.add_argument("dest", help="Destination directory for 2D slices")
    args = parser.parse_args()

    os.makedirs(args.dest, exist_ok=True)

    with tifffile.TiffFile(args.src) as tif:
        pages = tif.series[0].pages
        n = len(pages)
        if n == 0:
            print(f"ERROR: {args.src} has no pages in series[0]", file=sys.stderr)
            sys.exit(1)
        width = max(5, len(str(n - 1)))
        for i, page in enumerate(pages):
            out = os.path.join(args.dest, f"slice_{i:0{width}d}.tiff")
            tifffile.imwrite(out, page.asarray())

    print(f"Wrote {n} slices to {args.dest}")


if __name__ == "__main__":
    main()
