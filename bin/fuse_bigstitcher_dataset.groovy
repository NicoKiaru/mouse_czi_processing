#@CommandService cs
#@String xml_file
#@String output_directory
#@String fusion_method
#@double downsample_x
#@double downsample_y
#@double downsample_z

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
        "x_downsample", downsample_x,
        "y_downsample", downsample_y,
        "z_downsample", downsample_z,
        "fusion_method", fusion_method
    ).get();


import ch.epfl.biop.scijava.command.spimdata.FuseBigStitcherDatasetIntoOMETiffCommand
import org.scijava.command.CommandService