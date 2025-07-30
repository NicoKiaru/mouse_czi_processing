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

        String mirrorTransformName = "Mirror Transform"

        List<ViewTransform> allTransforms = dataset.getViewRegistrations().getViewRegistrationsOrdered().get(0).getTransformList()

        Optional<ViewTransform> flipTransform = allTransforms.stream().filter { viewTransform -> 
            viewTransform.hasName() && viewTransform.getName().contains(mirrorTransformName)
        }.findFirst()

        println("INFO: Flipping along X axis")
        
        if (!flipTransform.isPresent()) {

            def transform = new AffineTransform3D()
            transform.set(
                -1.0, 0.0, 0.0, 0.0,
                0.0, 1.0, 0.0, 0.0,
                0.0, 0.0, 1.0, 0.0
            )

            dataset.getViewRegistrations()
                   .getViewRegistrations()
                   .values()
                   .forEach{viewRegistration -> 
                                viewRegistration.preconcatenateTransform(new ViewTransformAffine(mirrorTransformName, transform))
                            }

            new XmlIoSpimData().save((SpimData) dataset, xml_file);


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
        
        SpimData dataset = new XmlIoSpimData().load(xml_file)
        ASR.t[originalOrientation].eachWithIndex { p, idx ->
            
            println("Apply transform: "+p)
            def matrix = getTransform(p)

            println("Matrix: "+matrix)
            dataset.getViewRegistrations()
                   .getViewRegistrations()
                   .values()
                   .forEach{viewRegistration -> 
                                viewRegistration.preconcatenateTransform(new ViewTransformAffine("ASR Transform "+idx, matrix))
                            }

        }
        new XmlIoSpimData().save((SpimData) dataset, xml_file);

    } else {
        // Otherwise inform that it's not going to be done and mention which transforms are available
        println("We do not have a transformation from ${originalOrientation} to 'ASR' Skipping reorientation step")
        println("Available Transformations to ASR are from the following orientations ${ASR.t.keySet()}")
        return
    }

}

static AffineTransform3D getTransform(rotation) {
    println(rotation)
    
    // Start with identity matrix
    def transform = new AffineTransform3D()
    
    // Apply rotations in sequence
    def axis = rotation.axis
    def angleDegrees = rotation.angle as double
    println(axis)
    println(angleDegrees)
    def angleRadians = Math.toRadians(angleDegrees)
    println(angleRadians)
    def rotationTransform = new AffineTransform3D()
    println(rotationTransform)
    
    switch (axis) {
        case "x-axis":
            rotationTransform.set(
                1.0, 0.0, 0.0, 0.0,
                0.0, Math.cos(angleRadians), -Math.sin(angleRadians), 0.0,
                0.0, Math.sin(angleRadians), Math.cos(angleRadians), 0.0
            )
            break
        case "y-axis":
            rotationTransform.set(
                Math.cos(angleRadians), 0.0, Math.sin(angleRadians), 0.0,
                0.0, 1.0, 0.0, 0.0,
                -Math.sin(angleRadians), 0.0, Math.cos(angleRadians), 0.0
            )
            break
        case "z-axis":
            rotationTransform.set(
                Math.cos(angleRadians), -Math.sin(angleRadians), 0.0, 0.0,
                Math.sin(angleRadians), Math.cos(angleRadians), 0.0, 0.0,
                0.0, 0.0, 1.0, 0.0
            )
            break
        default:
            throw new IllegalArgumentException("Unknown axis: ${axis}")
    }
    
    // Concatenate the rotation (multiply matrices)
    return rotationTransform

}


import mpicbg.spim.data.SpimData
import mpicbg.spim.data.SpimDataException
import mpicbg.spim.data.XmlIoSpimData
import mpicbg.spim.data.registration.ViewTransform
import mpicbg.spim.data.registration.ViewTransformAffine;
import net.imglib2.realtransform.AffineTransform3D