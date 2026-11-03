import Foundation

enum CanvasDocumentJSON {
    static func fields(of document: CanvasDocument) -> [String: JSONValue]? {
        var withoutComments = document
        withoutComments.comments = []
        guard let body = try? CanvasDocumentCodec.encode(withoutComments),
              case .object(var fields)? = JSONValue.parse(body) else { return nil }
        fields["comments"] = nil
        return fields
    }
}
