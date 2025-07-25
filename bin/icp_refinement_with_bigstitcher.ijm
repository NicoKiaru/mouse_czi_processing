#@String xml_file
#@String icp_refinement_type
#@String downsampling
#@String interest
#@String icp_max_error

// Print parameters for debugging
print("ICP Refinement Parameters:");
print("XML file: " + xml_file);
print("ICP refinement type: " + icp_refinement_type);
print("Downsampling: " + downsampling);
print("Interest: " + interest);
print("ICP max error: " + icp_max_error);

// Perform ICP (Iterative Closest Point) refinement
print("Starting ICP refinement...");
run("ICP Refinement ...",
    "select=[" + xml_file + "] " +
    "process_angle=[All angles] " +
    "process_channel=[All channels] " +
    "process_illumination=[All illuminations] " +
    "process_tile=[All tiles] " +
    "process_timepoint=[All Timepoints] " +
    "icp_refinement_type=[" + icp_refinement_type + "] " +
    "downsampling=[" + downsampling + "] " +
    "interest=[" + interest + "] " +
    "icp_max_error=[" + icp_max_error + "]"
);

print("ICP refinement completed successfully!");
print("Processed XML file: " + xml_file);