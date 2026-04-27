import SwiftUI
import UIKit

struct SharedHTMLText: View {
    let html: String
    var font: UIFont = .preferredFont(forTextStyle: .body)
    var textColor: UIColor = .label

    var body: some View {
        if let attributedText = makeAttributedString() {
            Text(attributedText)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(html.removingHTMLTags())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func makeAttributedString() -> AttributedString? {
        guard let data = """
        <span style="font-family: -apple-system; font-size: \(font.pointSize)px; color: \(textColor.hexString);">\(html)</span>
        """.data(using: .utf8),
        let attributedString = try? NSMutableAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        ) else {
            return nil
        }

        attributedString.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: attributedString.length)) { value, range, _ in
            if value == nil {
                attributedString.addAttribute(.foregroundColor, value: textColor, range: range)
            }
        }

        return try? AttributedString(attributedString, including: \.uiKit)
    }
}

private extension UIColor {
    var hexString: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(
            format: "#%02X%02X%02X",
            Int(red * 255),
            Int(green * 255),
            Int(blue * 255)
        )
    }
}

extension String {
    func removingHTMLTags() -> String {
        replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#039;", with: "'")
    }
}
