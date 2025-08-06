#@CommandService cs
#@String xml_file
#@String output_directory
#@String fusion_method
#@double downsample

cs.run(
        FuseBigStitcherDatasetIntoOMETiffCommand.class, true,
        "xml_bigstitcher_file", new File(xml_file),
        "output_path_directory", new File(output_directory),
        "range_channels", "",
        "range_slices", "",
        "range_frames", "",
        "n_resolution_levels", 1,
        "use_lzw_compression", false,
        "split_slices", false,
        "split_channels", true,
        "split_frames", false,
        "override_z_ratio", false,
        "use_interpolation", false,
        "x_downsample", downsample,
        "y_downsample", downsample,
        "z_downsample", downsample,
        "fusion_method", fusion_method
    ).get();


import ch.epfl.biop.scijava.command.spimdata.FuseBigStitcherDatasetIntoOMETiffCommand
import org.scijava.command.CommandService