#@String image_file_path
#@String output_directory

import loci.formats.ImageReader
import loci.formats.meta.MetadataRetrieve
import loci.formats.services.OMEXMLServiceImpl
import loci.common.services.ServiceFactory
import loci.formats.services.OMEXMLService
import ome.units.UNITS

// Retrieve the number of channels as well as the voxel sizes (x, y, z)
ImageReader reader = new ImageReader()

// Set up metadata service
ServiceFactory factory = new ServiceFactory()
OMEXMLService service = factory.getInstance(OMEXMLService.class)
def meta = service.createOMEXMLMetadata()
reader.setMetadataStore(meta)

// Initialize the reader with the file
reader.setId(image_file_path)

// Get number of channels
int channelCount = reader.getSizeC()

// Get voxel size (physical pixel size)
def pixelSizeX = meta.getPixelsPhysicalSizeX(0)
def pixelSizeY = meta.getPixelsPhysicalSizeY(0)
def pixelSizeZ = meta.getPixelsPhysicalSizeZ(0)

println "File: ${image_file_path}"
println "Number of channels: ${channelCount}"
println "Voxel size:"

// Convert all sizes to microns using Bio-Formats built-in conversion
def xSizeMicrons = pixelSizeX != null ? pixelSizeX.value(UNITS.MICROMETER) : null
def ySizeMicrons = pixelSizeY != null ? pixelSizeY.value(UNITS.MICROMETER) : null
def zSizeMicrons = pixelSizeZ != null ? pixelSizeZ.value(UNITS.MICROMETER) : null

// Display information
if (pixelSizeX != null) {
    println "  X: ${pixelSizeX.value()} ${pixelSizeX.unit().getSymbol()} (${xSizeMicrons} µm)"
} else {
    println "  X: Not available"
}

if (pixelSizeY != null) {
    println "  Y: ${pixelSizeY.value()} ${pixelSizeY.unit().getSymbol()} (${ySizeMicrons} µm)"
} else {
    println "  Y: Not available"
}

if (pixelSizeZ != null) {
    println "  Z: ${pixelSizeZ.value()} ${pixelSizeZ.unit().getSymbol()} (${zSizeMicrons} µm)"
} else {
    println "  Z: Not available"
}

// Additional useful information
println "Image dimensions:"
println "  Width: ${reader.getSizeX()} pixels"
println "  Height: ${reader.getSizeY()} pixels"
println "  Z-slices: ${reader.getSizeZ()}"
println "  Time points: ${reader.getSizeT()}"

// Save voxel sizes to file
File outputDir = new File(output_directory)
if (!outputDir.exists()) {
    outputDir.mkdirs()
}

File outputFile = new File(outputDir, "voxel_sizes.txt")

try {
    outputFile.withWriter { writer ->
        // Write X, Y, Z on separate lines in microns
        // Use "N/A" if the value is not available
        writer.writeLine(xSizeMicrons != null ? xSizeMicrons.toString() : "N/A")
        writer.writeLine(ySizeMicrons != null ? ySizeMicrons.toString() : "N/A")
        writer.writeLine(zSizeMicrons != null ? zSizeMicrons.toString() : "N/A")
    }
    println "\nVoxel sizes saved to: ${outputFile.absolutePath}"
} catch (Exception e) {
    println "Error writing to file: ${e.message}"
}

// Close the reader
reader.close()