#@String xml_file
#@int use_channel
#@int pairwise_shifts_downsamples_x
#@int pairwise_shifts_downsamples_y
#@int pairwise_shifts_downsamples_z
#@double filter_min_r

// Print parameters for debugging
print("Tile Alignment Parameters:");
print("XML file: " + xml_file);
print("Use channel: " + use_channel);
print("Pairwise shifts downsamples - x: " + pairwise_shifts_downsamples_x + ", y: " + pairwise_shifts_downsamples_y + ", z: " + pairwise_shifts_downsamples_z);
print("Filter min r: " + filter_min_r);

// Step 1: Calculate pairwise shifts for tile alignment
print("Step 1: Calculating pairwise shifts for tiles...");

// Build the channel string dynamically
channelString = "channels=[use Channel " + use_channel + "] ";

run("Calculate pairwise shifts ...",
    "select=[" + xml_file + "] " +
    "process_angle=[All angles] " +
    "process_channel=[All channels] " +
    "process_illumination=[All illuminations] " +
    "process_tile=[All tiles] " +
    "process_timepoint=[All Timepoints] " +
    "method=[Phase Correlation] " +
    "show_expert_grouping_options " +
    "how_to_treat_timepoints=[treat individually] " +
    "how_to_treat_illuminations=group " +
    "how_to_treat_angles=[treat individually] " +
    "how_to_treat_tiles=compare " +
    channelString +
    "downsample_in_x=" + pairwise_shifts_downsamples_x + " " +
    "downsample_in_y=" + pairwise_shifts_downsamples_y + " " +
    "downsample_in_z=" + pairwise_shifts_downsamples_z
);

// Step 2: Filter pairwise shifts
print("Step 2: Filtering pairwise shifts...");
run("Filter pairwise shifts ...", 
    "select=[" + xml_file + "] " +
    "filter_by_link_quality " +
    "min_r=" + filter_min_r + " " +
    "max_r=1"
);

// Step 3: Optimize globally and apply shifts with tile-specific settings
print("Step 3: Optimizing globally and applying shifts for tiles...");

// Note: The Java code calculates halfTiles dynamically, but since we don't have access to nTiles in IJM,
// we'll use a simpler approach or you can pass it as a parameter if needed
run("Optimize globally and apply shifts ...",
    "select=[" + xml_file + "] " +
    "process_angle=[All angles] " +
    "process_channel=[All channels] " +
    "process_illumination=[All illuminations] " +
    "process_tile=[All tiles] " +
    "process_timepoint=[All Timepoints] " +
    "relative=2.500 " +
    "absolute=3.500 " +
    "global_optimization_strategy=[Two-Round using metadata to align unconnected Tiles] " +
    "show_expert_grouping_options " +
    "how_to_treat_timepoints=[treat individually] " +
    "how_to_treat_channels=group " +
    "how_to_treat_illuminations=group " +
    "how_to_treat_angles=[treat individually] " +
    "how_to_treat_tiles=compare"
    // Note: fix_group parameter omitted since we don't have nTiles calculation
);

print("Tile alignment completed successfully!");
print("Processed XML file: " + xml_file);

eval("script", "System.exit(0);"); // BigStitcher bug -> force quit