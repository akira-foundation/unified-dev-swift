import Foundation

public enum LossyList {
    public static func decode<Element: Decodable>(
        _ type: Element.Type,
        from data: Data,
        decoder: JSONDecoder = JSONDecoder()
    ) -> [Element]? {
        guard let list = try? decoder.decode(Elements<Element>.self, from: data) else { return nil }
        return list.values
    }

    private struct Elements<Element: Decodable>: Decodable {
        let values: [Element]

        init(from decoder: any Decoder) throws {
            var container = try decoder.unkeyedContainer()
            var values: [Element] = []
            while !container.isAtEnd {
                if let element = try container.decode(Slot<Element>.self).value {
                    values.append(element)
                }
            }
            self.values = values
        }
    }

    private struct Slot<Element: Decodable>: Decodable {
        let value: Element?

        init(from decoder: any Decoder) throws {
            value = try? Element(from: decoder)
        }
    }
}
