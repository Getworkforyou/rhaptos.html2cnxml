import Foundation
import Kanna

/// XHTML Premailer - Converts CSS styles to inline HTML attributes
public class XHTMLPremailer {

    private let html: String
    private let baseURL: String?
    private let excludePseudoclasses: Bool
    private let keepStyleTags: Bool
    private let includeStarSelectors: Bool

    public init(html: String,
                baseURL: String? = nil,
                excludePseudoclasses: Bool = false,
                keepStyleTags: Bool = false,
                includeStarSelectors: Bool = false) {
        self.html = html
        self.baseURL = baseURL
        self.excludePseudoclasses = excludePseudoclasses
        self.keepStyleTags = keepStyleTags
        self.includeStarSelectors = includeStarSelectors
    }

    /// Transform the HTML by converting CSS to inline styles
    /// - Returns: Transformed HTML string
    public func transform() throws -> String {
        guard let doc = try? XML(xml: html, encoding: .utf8) else {
            throw PremailerError.couldNotParseHTML
        }

        // Extract and parse CSS rules from <style> tags
        var rules: [(selector: String, style: String)] = []

        for styleNode in doc.xpath("//xhtml:style", namespaces: ["xhtml": "http://www.w3.org/1999/xhtml"]) {
            if let cssBody = styleNode.text {
                let parsedRules = parseStyleRules(cssBody)
                rules.append(contentsOf: parsedRules)

                // Remove style tag if not keeping it
                if !keepStyleTags {
                    styleNode.removeFromParent()
                }
            }
        }

        // Apply CSS rules to matching elements
        for (selector, style) in rules {
            // Skip pseudoclasses if configured
            var cleanSelector = selector
            var pseudoclass = ""

            if selector.contains(":") {
                let parts = selector.split(separator: ":", maxSplits: 1)
                cleanSelector = String(parts[0])
                pseudoclass = parts.count > 1 ? ":\(parts[1])" : ""

                if excludePseudoclasses && !pseudoclass.isEmpty {
                    continue
                }
            }

            // Convert selector to XPath
            let xpath = convertSelectorToXPath(cleanSelector)

            for element in doc.xpath(xpath, namespaces: ["xhtml": "http://www.w3.org/1999/xhtml"]) {
                let oldStyle = element["style"] ?? ""
                let newStyle = mergeStyles(old: oldStyle, new: style, pseudoclass: pseudoclass)
                element["style"] = newStyle

                // Convert styles to basic HTML attributes
                styleToBasicHTMLAttributes(element: element, style: newStyle)
            }
        }

        // Remove all class attributes
        for element in doc.xpath("//@class") {
            if let parent = element.parent {
                parent.removeAttribute("class")
            }
        }

        return doc.toXML ?? html
    }

    /// Parse CSS rules from a CSS body string
    private func parseStyleRules(_ cssBody: String) -> [(selector: String, style: String)] {
        var rules: [(selector: String, style: String)] = []

        // Remove CSS comments
        let cleanedCSS = cssBody.replacingOccurrences(
            of: "/\\*.*?\\*/",
            with: "",
            options: .regularExpression
        )

        // Parse CSS rules
        let pattern = "([^{]+)\\{([^}]+)\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return rules
        }

        let matches = regex.matches(in: cleanedCSS, range: NSRange(cleanedCSS.startIndex..., in: cleanedCSS))

        for match in matches {
            guard match.numberOfRanges >= 3,
                  let selectorsRange = Range(match.range(at: 1), in: cleanedCSS),
                  let bulkRange = Range(match.range(at: 2), in: cleanedCSS) else {
                continue
            }

            let selectors = String(cleanedCSS[selectorsRange])
            var bulk = String(cleanedCSS[bulkRange])

            // Clean up the style bulk
            bulk = bulk.trimmingCharacters(in: .whitespacesAndNewlines)
            bulk = bulk.replacingOccurrences(of: ";\\s+", with: ";", options: .regularExpression)
            bulk = bulk.replacingOccurrences(of: ":\\s+", with: ":", options: .regularExpression)
            if bulk.hasSuffix(";") {
                bulk = String(bulk.dropLast())
            }

            // Split selectors by comma
            for selector in selectors.split(separator: ",") {
                let trimmedSelector = selector.trimmingCharacters(in: .whitespacesAndNewlines)

                // Skip star selectors if not including them
                if trimmedSelector == "*" && !includeStarSelectors {
                    continue
                }

                rules.append((selector: trimmedSelector, style: bulk))
            }
        }

        return rules
    }

    /// Merge old and new style strings
    private func mergeStyles(old: String, new: String, pseudoclass: String) -> String {
        var oldStyles = parseStyleDict(old)
        let newStyles = parseStyleDict(new)

        // New styles override old ones
        for (key, value) in newStyles {
            oldStyles[key] = value
        }

        return oldStyles.map { "\($0.key):\($0.value)" }.joined(separator: "; ")
    }

    /// Parse a style string into a dictionary
    private func parseStyleDict(_ style: String) -> [String: String] {
        var dict: [String: String] = [:]

        for part in style.split(separator: ";") {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            let components = trimmed.split(separator: ":", maxSplits: 1)

            if components.count == 2 {
                let key = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let value = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                dict[key] = value
            }
        }

        return dict
    }

    /// Convert CSS selector to XPath
    private func convertSelectorToXPath(_ selector: String) -> String {
        var xpath = selector

        // Handle class selectors
        if selector.starts(with: ".") {
            let className = String(selector.dropFirst())
            return "//*[contains(@class, '\(className)')]"
        }

        // Handle ID selectors
        if selector.starts(with: "#") {
            let id = String(selector.dropFirst())
            return "//*[@id='\(id)']"
        }

        // Add XHTML namespace for element selectors
        if !selector.contains("/") && !selector.starts(with: ".") && !selector.starts(with: "#") {
            xpath = "//xhtml:\(selector)"
        }

        return xpath
    }

    /// Convert CSS styles to basic HTML attributes
    private func styleToBasicHTMLAttributes(element: XMLElement, style: String) {
        let styles = parseStyleDict(style)

        for (key, value) in styles {
            switch key {
            case "text-align":
                if element["align"] == nil {
                    element["align"] = value
                }
            case "background-color":
                if element["bgcolor"] == nil {
                    element["bgcolor"] = value
                }
            case "width":
                if element["width"] == nil {
                    var widthValue = value
                    if widthValue.hasSuffix("px") {
                        widthValue = String(widthValue.dropLast(2))
                    }
                    element["width"] = widthValue
                }
            default:
                break
            }
        }
    }
}

public enum PremailerError: Error {
    case couldNotParseHTML
}
