import Foundation

struct Link: Codable, Identifiable {
    var url: String
    var title: String
    var added: Date
    /// 用户自己起的名称；为空时显示网页标题。
    var customName: String?
    /// 删除时间，只有删除历史里的条目有。
    var removed: Date?

    var id: String { url }

    var displayName: String {
        if let customName, !customName.isEmpty { return customName }
        if !title.isEmpty { return title }
        if let parsed = URL(string: url) {
            let name = parsed.isFileURL ? parsed.lastPathComponent : (parsed.host ?? "") + parsed.path
            if !name.isEmpty { return name }
        }
        return url
    }
}

/// 保存的网页在 links.json，删除历史在 history.json，都在 ~/Library/Application Support/拾页/ 下，新的排在最前。
final class Store: ObservableObject {
    @Published private(set) var links: [Link]
    @Published private(set) var history: [Link]
    private let linksFile: URL
    private let historyFile: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("拾页", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        linksFile = dir.appendingPathComponent("links.json")
        historyFile = dir.appendingPathComponent("history.json")
        links = Store.load(linksFile).map { link in
            var link = link
            link.title = Store.visibleText(link.title)
            return link
        }
        history = Store.load(historyFile)
    }

    /// 同一地址只记一次，再加时只更新标题；删除历史里有这个地址时取回来，保留之前起的名称。
    func add(url: String, title: String) {
        let title = Store.visibleText(title)
        if let i = links.firstIndex(where: { $0.url == url }) {
            if !title.isEmpty { links[i].title = title }
        } else {
            var link = history.first { $0.url == url } ?? Link(url: url, title: title, added: Date())
            if !title.isEmpty { link.title = title }
            link.added = Date()
            link.removed = nil
            history.removeAll { $0.url == url }
            links.insert(link, at: 0)
        }
        save()
    }

    /// 名称为空或和网页标题一样时，视为没有自定义名称。
    func rename(url: String, to name: String) {
        guard let i = links.firstIndex(where: { $0.url == url }) else { return }
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        links[i].customName = name.isEmpty || name == links[i].title ? nil : name
        save()
    }

    /// 删除的网页移到删除历史。
    func remove(url: String) {
        guard let i = links.firstIndex(where: { $0.url == url }) else { return }
        var link = links.remove(at: i)
        link.removed = Date()
        history.removeAll { $0.url == url }
        history.insert(link, at: 0)
        save()
    }

    func restore(url: String) {
        guard let i = history.firstIndex(where: { $0.url == url }) else { return }
        var link = history.remove(at: i)
        link.removed = nil
        links.insert(link, at: 0)
        save()
    }

    func purge(url: String) {
        history.removeAll { $0.url == url }
        save()
    }

    func clearHistory() {
        history.removeAll()
        save()
    }

    /// 去掉标题里看不见的格式字符（飞书会在标题里夹一串零宽字符做水印）。
    private static func visibleText(_ text: String) -> String {
        String(String.UnicodeScalarView(text.unicodeScalars.filter { $0.properties.generalCategory != .format }))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func load(_ file: URL) -> [Link] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: file) else { return [] }
        return (try? decoder.decode([Link].self, from: data)) ?? []
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(links) { try? data.write(to: linksFile, options: .atomic) }
        if let data = try? encoder.encode(history) { try? data.write(to: historyFile, options: .atomic) }
    }
}
