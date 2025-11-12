import Foundation
import RhaptosHTML2CNXML

let TESTBED_INPUT_DIR = "testbed_html"
let TESTBED_INPUT_FILEEXT = "*.htm*"
let TESTBED_OUTPUT_DIR = "testbed_html_output"

/// Check if Java is installed
func javaInstalled() -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["java", "-version"]
    process.standardOutput = Pipe()
    process.standardError = Pipe()

    do {
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    } catch {
        return false
    }
}

/// Print a status message with decorative borders
func printStatus(_ message: String) {
    let border = String(repeating: "=", count: 79)
    print(border)
    print(message)
    print(border)
}

/// Validate CNXML file with Jing
func jingValidateFile(xmlFilename: String, logFilename: String) {
    let jingJar = "jing/jing.jar"
    let jingRng = "jing/cnxml-jing.rng"

    printStatus("Validating \(xmlFilename) ...")

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["java", "-jar", jingJar, jingRng, xmlFilename]

    let outputPipe = Pipe()
    let errorPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = errorPipe

    do {
        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        var logContent = ""
        if !outputData.isEmpty {
            logContent += String(data: outputData, encoding: .utf8) ?? ""
        }
        if !errorData.isEmpty {
            logContent += String(data: errorData, encoding: .utf8) ?? ""
        }

        try logContent.write(toFile: logFilename, atomically: true, encoding: .utf8)
    } catch {
        print("Error during validation: \(error)")
    }
}

/// Main transformation function
func main() {
    // Check Java installation
    if !javaInstalled() {
        print("ERROR: Could not find Java. Please ensure that Java is installed and available.")
        exit(1)
    }

    // Create output directory if it doesn't exist
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: TESTBED_OUTPUT_DIR) {
        try? fileManager.createDirectory(atPath: TESTBED_OUTPUT_DIR,
                                         withIntermediateDirectories: true)
    }

    // Get all HTML files in testbed directory
    let testbedPath = fileManager.currentDirectoryPath + "/" + TESTBED_INPUT_DIR
    guard let enumerator = fileManager.enumerator(atPath: testbedPath) else {
        print("ERROR: Could not access testbed directory")
        exit(1)
    }

    // Initialize transformer
    let transformer = HTMLSoup2CNXML()

    // Process each HTML file
    for case let filename as String in enumerator where filename.hasSuffix(".htm") || filename.hasSuffix(".html") {
        let htmlFilename = "\(TESTBED_INPUT_DIR)/\(filename)"
        let justFilename = (filename as NSString).lastPathComponent
        let justFilenameNoExt = (justFilename as NSString).deletingPathExtension
        let cnxmlFilename = "\(TESTBED_OUTPUT_DIR)/\(justFilenameNoExt).xml"
        let jingLogFilename = "\(TESTBED_OUTPUT_DIR)/\(justFilenameNoExt).log"

        // Read HTML file
        guard let htmlContent = try? String(contentsOfFile: htmlFilename, encoding: .utf8) else {
            print("Warning: Could not read \(htmlFilename)")
            continue
        }

        printStatus("Transforming \(justFilename) ...")

        do {
            // Transform HTML to CNXML
            let (cnxml, images, title) = try transformer.htmlsoupToCNXML(
                content: htmlContent,
                downloadImages: true,
                baseURL: "."
            )

            // Write image files
            for (imageFilename, imageData) in images {
                let imagePath = "\(TESTBED_OUTPUT_DIR)/\(imageFilename)"
                try imageData.write(to: URL(fileURLWithPath: imagePath))
            }

            // Write CNXML output
            try cnxml.write(toFile: cnxmlFilename, atomically: true, encoding: .utf8)

            // Validate with Jing
            let skipValidation = CommandLine.arguments.contains("-noval")
            if skipValidation {
                printStatus("Validation skipped")
            } else {
                printStatus("Validating...")
                jingValidateFile(xmlFilename: cnxmlFilename, logFilename: jingLogFilename)
            }

        } catch {
            print("ERROR transforming \(htmlFilename): \(error)")
        }
    }

    printStatus("Finished!")
}

// Run main function
main()
