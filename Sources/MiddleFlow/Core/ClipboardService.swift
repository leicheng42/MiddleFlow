import AppKit
import Foundation

struct ClipboardSnapshot {
    let entries: [[NSPasteboard.PasteboardType: Data]]
}

struct ClipboardWrite {
    let previous: ClipboardSnapshot
    let changeCount: Int
    let text: String
}

final class ClipboardService {
    @discardableResult
    func copy(_ text: String) -> ClipboardWrite? {
        let pasteboard = NSPasteboard.general
        let previous = capture(pasteboard)
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else { return nil }
        return ClipboardWrite(
            previous: previous,
            changeCount: pasteboard.changeCount,
            text: text
        )
    }

    func isCurrent(_ write: ClipboardWrite) -> Bool {
        let pasteboard = NSPasteboard.general
        return pasteboard.changeCount == write.changeCount &&
            pasteboard.string(forType: .string) == write.text
    }

    func restore(_ snapshot: ClipboardSnapshot) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let items: [NSPasteboardItem] = snapshot.entries.map { entry in
            let item = NSPasteboardItem()
            for (type, data) in entry {
                item.setData(data, forType: type)
            }
            return item
        }
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }

    @discardableResult
    func restoreIfUnchanged(_ write: ClipboardWrite) -> Bool {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount == write.changeCount else { return false }
        restore(write.previous)
        return true
    }

    private func capture(_ pasteboard: NSPasteboard) -> ClipboardSnapshot {
        let entries: [[NSPasteboard.PasteboardType: Data]] = pasteboard.pasteboardItems?
            .map { item in
                var values: [NSPasteboard.PasteboardType: Data] = [:]
                for type in item.types {
                    if let data = item.data(forType: type) {
                        values[type] = data
                    }
                }
                return values
            }
            .filter { !$0.isEmpty } ?? []
        return ClipboardSnapshot(entries: entries)
    }
}
