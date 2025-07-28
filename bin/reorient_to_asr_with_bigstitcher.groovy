#@String xml_file
#@String raw_orientation
#@Boolean reorient_to_asr

// ASR class in Groovy
class ASR {
    static Map<String, List<Map<String, Object>>> t = [
        "ipl": [
            [axis: "y-axis", angle: 180],
            [axis: "x-axis", angle: -90]
        ],
        "ial": [
            [axis: "y-axis", angle: 180],
            [axis: "x-axis", angle: -90],
            [axis: "z-axis", angle: 180]
        ],
        "ras": [
            [axis: "y-axis", angle: -90],
            [axis: "x-axis", angle: 90]
        ],
        "sal": [
            [axis: "y-axis", angle: 180],
            [axis: "x-axis", angle: 90]
        ],
        "psl": [
            [axis: "y-axis", angle: 180]
        ],
        "pir": [
            [axis: "x-axis", angle: 180]
        ],
        "lai": [
            [axis: "y-axis", angle: -90],
            [axis: "x-axis", angle: 90]
        ],
        "iar": [
            [axis: "x-axis", angle: 90]
        ],
        "ail": [
            [axis: "z-axis", angle: 180]
        ],
        "asr": [], // Empty list
        "rpi": [
            [axis: "y-axis", angle: -90],
            [axis: "x-axis", angle: -90]
        ],
        "lps": [
            [axis: "y-axis", angle: 90],
            [axis: "x-axis", angle: -90]
        ],
        "spr": [
            [axis: "x-axis", angle: -90]
        ]
    ]
}


// fixMirroring method converted to Groovy
String fixMirroring(String raw_orientation, String xml_file) {
    String orientation = raw_orientation.toLowerCase()
    Map<String, String> mirrorOrientations = [
        "psr": "psl",
        "pil": "pir",
        "rps": "ras",
        "sar": "sal",
        "lap": "lai",
        "ial": "iar",
        "air": "ail",
        "asl": "asr",
        "rai": "rpi",
        "ipr": "ipl",
        "lpi": "lps",
        "spl": "spr"
    ]

    if (mirrorOrientations.containsKey(orientation)) {
        SpimData dataset = new XmlIoSpimData().load(xml_file)

        List<ViewTransform> allTransforms = dataset.getViewRegistrations().getViewRegistrationsOrdered().get(0).getTransformList()

        Optional<ViewTransform> flipTransform = allTransforms.stream().filter { viewTransform -> 
            viewTransform.hasName() && viewTransform.getName().contains("Manually defined transformation (Rigid/Affine by matrix)")
        }.findFirst()

        //def flipTansform = xml.ViewRegistrations.ViewRegistration[0].ViewTransform.find{ it.Name.text().contains("Manually defined transformation (Rigid/Affine by matrix)") }

        println("INFO: Flipping along X axis")

        if (!flipTransform.isPresent()) {
            ij.IJ.run("Apply Transformations", "select=["+xml_file+"] " +
                "apply_to_angle=[All angles] " +
                "apply_to_channel=[All channels] " +
                "apply_to_illumination=[All illuminations] " +
                "apply_to_tile=[All tiles] " +
                "apply_to_timepoint=[All Timepoints] " +
                "transformation=Rigid " +
                "apply=[Current view transformations (appends to current transforms)] " +
                "define=Matrix " +
                "same_transformation_for_all_channels " +
                "same_transformation_for_all_tiles " +
                "timepoint_0_all_channels_illumination_0_angle_0=[-1.0, 0.0, 0.0, 0.0, " +
                "0.0, 1.0, 0.0, 0.0, " +
                "0.0, 0.0, 1.0, 0.0]")

            println("INFO: Flipping along X axis DONE")
        } else {
            println("INFO: Flipping along X axis not necessary, already in XML metadata")
        }

        return mirrorOrientations[orientation]
    } else {
        println("INFO: Orientation ${orientation} not in flipped orientation database, returning orientation as-is")
        return orientation
    }
}

int getNChannels(String xml_file) {
    SpimData dataset = new XmlIoSpimData().load(xml_file)
    return dataset.getSequenceDescription().getAllChannels().size();
}

// Make sure that it is written in caps
String originalOrientation = fixMirroring(raw_orientation, xml_file)

int nChannels = getNChannels(xml_file)

if (reorient_to_asr) {

    // If the transformation exists, then use it
    if (ASR.t.containsKey(originalOrientation)) {
        ASR.t[originalOrientation].each { p ->
            // Build the command
            String command = "select=[" + xml_file + "] " +
                "apply_to_angle=[All angles] " +
                "apply_to_channel=[All channels] " +
                "apply_to_illumination=[All illuminations] " +
                "apply_to_tile=[All tiles] " +
                "apply_to_timepoint=[All Timepoints] " +
                "transformation=Rigid " +
                "apply=[Current view transformations (appends to current transforms)] " +
                "define=[Rotation around axis] " +
                "same_transformation_for_all_channels " +
                "same_transformation_for_all_tiles "

            // UNTESTED WITH MULTIPLE CHANNELS!!
            if (nChannels == 1) {
                command += "axis_timepoint_0_channel_0_illumination_0_angle_0=${p.axis} " +
                    "rotation_timepoint_0_channel_0_illumination_0_angle_0=${p.angle}"
            } else {
                command += "axis_timepoint_0_all_channels_illumination_0_angle_0=${p.axis} " +
                    "rotation_timepoint_0_all_channels_illumination_0_angle_0=${p.angle}"
            }

            ij.IJ.log(command)

            // Run it
            ij.IJ.run("Apply Transformations", command)
        }
    } else {
        // Otherwise inform that it's not going to be done and mention which transforms are available
        println("We do not have a transformation from ${originalOrientation} to 'ASR' Skipping reorientation step")
        println("Available Transformations to ASR are from the following orientations ${ASR.t.keySet()}")
        return
    }

}


import mpicbg.spim.data.SpimData
import mpicbg.spim.data.SpimDataException
import mpicbg.spim.data.XmlIoSpimData
import mpicbg.spim.data.registration.ViewTransform