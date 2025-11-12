import Foundation
import SwiftSoup
import Kanna

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Main HTML to CNXML transformation module
public class HTMLSoup2CNXML {

    private let currentDir: String
    private let xhtmlEntities: String
    private let xhtml2cnxmlXSL1: String
    private let xhtml2cnxmlXSL2: String

    public init(currentDir: String? = nil) {
        if let dir = currentDir {
            self.currentDir = dir
        } else {
            self.currentDir = FileManager.default.currentDirectoryPath
        }

        self.xhtmlEntities = "\(self.currentDir)/www/catalog_xhtml/catalog.xml"
        self.xhtml2cnxmlXSL1 = "\(self.currentDir)/www/xhtml2cnxml_meta1.xsl"
        self.xhtml2cnxmlXSL2 = "\(self.currentDir)/www/xhtml2cnxml_meta2.xsl"
    }

    /// Transform HTML content to CNXML
    /// - Parameters:
    ///   - content: HTML content string
    ///   - downloadImages: Whether to download images from URLs
    ///   - baseURL: Base URL for resolving relative image URLs
    /// - Returns: Tuple of (CNXML string, image objects dictionary, HTML title)
    public func htmlsoupToCNXML(content: String,
                                downloadImages: Bool = false,
                                baseURL: String = ".") throws -> (cnxml: String, images: [String: Data], title: String) {
        return try xslTransform(content: content,
                                downloadImages: downloadImages,
                                baseURL: baseURL)
    }

    /// Main transformation method
    private func xslTransform(content: String,
                              downloadImages: Bool,
                              baseURL: String) throws -> (cnxml: String, images: [String: Data], title: String) {

        var htmlTitle = "Untitled"

        // Step 1: Tidy and premail the HTML
        let tidiedHTML = try tidyAndPremail(content: content)

        // Step 2: Load XHTML catalog (for libxml2)
        // Note: In Swift, we'll use the libxml2 C API directly
        loadXMLCatalog(xhtmlEntities)

        // Step 3: First XSLT transformation
        guard let result1 = applyXSLT(xml: tidiedHTML, xslt: xhtml2cnxmlXSL1) else {
            throw HTML2CNXMLError.xsltTransformationFailed
        }

        // Step 4: Parse with Kanna for image processing
        guard var xmlDoc = try? XML(xml: result1, encoding: .utf8) else {
            throw HTML2CNXMLError.xmlParsingFailed
        }

        // Step 5: Download images if requested
        var imageObjects: [String: Data] = [:]
        if downloadImages {
            imageObjects = try downloadImagesFromXML(xmlDoc: &xmlDoc, baseURL: baseURL)
        }

        // Step 6: Add title
        xmlDoc = try addCNXMLTitle(xmlDoc: xmlDoc, title: htmlTitle)

        // Step 7: Convert back to string
        guard let xmlString = xmlDoc.toXML else {
            throw HTML2CNXMLError.xmlSerializationFailed
        }

        // Step 8: Second XSLT transformation
        guard let result2 = applyXSLT(xml: xmlString, xslt: xhtml2cnxmlXSL2) else {
            throw HTML2CNXMLError.xsltTransformationFailed
        }

        return (cnxml: result2, images: imageObjects, title: htmlTitle)
    }

    /// Tidy HTML and apply CSS premailer
    private func tidyAndPremail(content: String) throws -> String {
        // Use SwiftSoup to clean and normalize HTML
        let doc = try SwiftSoup.parse(content)
        doc.outputSettings()
            .syntax(Syntax.xml)
            .escapeMode(Entities.EscapeMode.xhtml)
            .charset(.utf8)
            .prettyPrint(false)

        // Convert to XHTML string
        var xhtml = try doc.html()

        // Add XHTML namespace if not present
        if !xhtml.contains("xmlns=\"http://www.w3.org/1999/xhtml\"") {
            xhtml = xhtml.replacingOccurrences(
                of: "<html>",
                with: "<html xmlns=\"http://www.w3.org/1999/xhtml\">"
            )
        }

        // Apply XHTML Premailer
        let premailer = XHTMLPremailer(html: xhtml)
        do {
            return try premailer.transform()
        } catch {
            // If premailer fails, return tidied HTML
            return xhtml
        }
    }

    /// Load XML catalog for entity resolution
    private func loadXMLCatalog(_ catalogPath: String) {
        // Load catalog using libxml2 C API
        catalogPath.withCString { cPath in
            xmlLoadCatalog(cPath)
        }
        xmlLineNumbersDefault(1)
        xmlSubstituteEntitiesDefault(1)
    }

    /// Apply XSLT transformation
    private func applyXSLT(xml: String, xslt: String) -> String? {
        // Parse XML document
        guard let xmlDoc = xmlReadMemory(xml, Int32(xml.utf8.count), nil, nil, 0) else {
            return nil
        }
        defer { xmlFreeDoc(xmlDoc) }

        // Parse XSLT stylesheet
        guard let xsltDoc = xmlReadFile(xslt, nil, 0) else {
            return nil
        }

        guard let stylesheet = xsltParseStylesheetDoc(xsltDoc) else {
            xmlFreeDoc(xsltDoc)
            return nil
        }
        defer { xsltFreeStylesheet(stylesheet) }

        // Apply transformation
        guard let result = xsltApplyStylesheet(stylesheet, xmlDoc, nil) else {
            return nil
        }
        defer { xmlFreeDoc(result) }

        // Convert result to string
        var buffer: UnsafeMutablePointer<xmlChar>? = nil
        var length: Int32 = 0

        xsltSaveResultToString(&buffer, &length, result, stylesheet)

        guard let resultBuffer = buffer else {
            return nil
        }
        defer { xmlFree(resultBuffer) }

        return String(cString: resultBuffer)
    }

    /// Download images from XML document
    private func downloadImagesFromXML(xmlDoc: inout XMLDocument, baseURL: String) throws -> [String: Data] {
        var objects: [String: Data] = [:]

        let imageNodes = xmlDoc.xpath("//cnxtra:image",
                                      namespaces: ["cnxtra": "http://cnxtra"])

        for (position, imageNode) in imageNodes.enumerated() {
            guard let imageURL = imageNode["src"],
                  !imageURL.isEmpty,
                  !baseURL.isEmpty else {
                continue
            }

            // Construct full URL
            var fullURL = imageURL
            if baseURL != "." {
                if let base = URL(string: baseURL),
                   let url = URL(string: imageURL, relativeTo: base) {
                    fullURL = url.absoluteString
                }
            }

            do {
                // Download image
                let imageData = try downloadImage(from: fullURL)

                // Detect MIME type
                let mimeType = MagicMIME.whatis(imageData)

                // Only allow PNG, JPEG, GIF
                guard ["image/png", "image/jpeg", "image/gif"].contains(mimeType) else {
                    print("Warning: Unsupported image type \(mimeType) for \(fullURL)")
                    continue
                }

                imageNode["mime-type"] = mimeType

                // Generate image name
                let imageName = String(format: "gd-%04d", position + 1)
                let ext = MagicMIME.getExtension(for: mimeType) ?? "jpg"
                let fullImageName = "\(imageName).\(ext)"

                // Set alt text if missing
                if imageNode["alt"] == nil || imageNode["alt"]?.isEmpty == true {
                    imageNode["alt"] = imageURL
                }

                // Set image name as text content
                imageNode.text = fullImageName

                // Store image data
                objects[fullImageName] = imageData

            } catch {
                print("Warning: \(fullURL) could not be downloaded - \(error)")
            }
        }

        return objects
    }

    /// Download image from URL
    private func downloadImage(from urlString: String) throws -> Data {
        guard let url = URL(string: urlString) else {
            throw HTML2CNXMLError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<Data, Error>?

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                result = .failure(error)
            } else if let data = data {
                result = .success(data)
            } else {
                result = .failure(HTML2CNXMLError.downloadFailed)
            }
            semaphore.signal()
        }

        task.resume()
        semaphore.wait()

        guard let finalResult = result else {
            throw HTML2CNXMLError.downloadFailed
        }

        return try finalResult.get()
    }

    /// Add title to CNXML document
    private func addCNXMLTitle(xmlDoc: XMLDocument, title: String) throws -> XMLDocument {
        let titleNodes = xmlDoc.xpath("/cnxml:document/cnxml:title",
                                      namespaces: ["cnxml": "http://cnx.rice.edu/cnxml"])

        if let titleNode = titleNodes.first {
            titleNode.text = title
        }

        return xmlDoc
    }
}

public enum HTML2CNXMLError: Error {
    case xsltTransformationFailed
    case xmlParsingFailed
    case xmlSerializationFailed
    case invalidURL
    case downloadFailed
}

// MARK: - libxml2 and libxslt C API declarations

@_silgen_name("xmlLoadCatalog")
func xmlLoadCatalog(_ filename: UnsafePointer<CChar>) -> Int32

@_silgen_name("xmlLineNumbersDefault")
func xmlLineNumbersDefault(_ value: Int32)

@_silgen_name("xmlSubstituteEntitiesDefault")
func xmlSubstituteEntitiesDefault(_ value: Int32)

@_silgen_name("xmlReadMemory")
func xmlReadMemory(_ buffer: String, _ size: Int32, _ URL: UnsafePointer<CChar>?,
                   _ encoding: UnsafePointer<CChar>?, _ options: Int32) -> xmlDocPtr?

@_silgen_name("xmlReadFile")
func xmlReadFile(_ filename: String, _ encoding: UnsafePointer<CChar>?, _ options: Int32) -> xmlDocPtr?

@_silgen_name("xmlFreeDoc")
func xmlFreeDoc(_ doc: xmlDocPtr)

@_silgen_name("xmlFree")
func xmlFree(_ ptr: UnsafeMutableRawPointer)

@_silgen_name("xsltParseStylesheetDoc")
func xsltParseStylesheetDoc(_ doc: xmlDocPtr) -> xsltStylesheetPtr?

@_silgen_name("xsltFreeStylesheet")
func xsltFreeStylesheet(_ sheet: xsltStylesheetPtr)

@_silgen_name("xsltApplyStylesheet")
func xsltApplyStylesheet(_ sheet: xsltStylesheetPtr, _ doc: xmlDocPtr,
                         _ params: UnsafePointer<UnsafePointer<CChar>?>?) -> xmlDocPtr?

@_silgen_name("xsltSaveResultToString")
func xsltSaveResultToString(_ doc: UnsafeMutablePointer<UnsafeMutablePointer<xmlChar>?>,
                             _ len: UnsafeMutablePointer<Int32>,
                             _ result: xmlDocPtr,
                             _ style: xsltStylesheetPtr) -> Int32

typealias xmlDocPtr = OpaquePointer
typealias xsltStylesheetPtr = OpaquePointer
typealias xmlChar = UInt8
