import Foundation
import ZIPFoundation

/// An opened `.3mf` archive with a path index built from one central-directory walk.
///
/// ZIPFoundation's `archive[path]` rescans the whole central directory on every call, so a
/// crafted archive with many entries turns each lookup into a full walk. All 3MF lookups go
/// through ``entry(_:)`` instead.
///
/// Not thread-safe: the underlying `Archive` reads through one shared file handle.
final class ThreeMFArchive {
    /// Cap on central-directory entries indexed. High enough that part-heavy Bambu archives,
    /// which list `3D/Objects/*.model` before `Metadata/`, still reach plate PNGs. Bounds
    /// pathological million-entry ZIPs.
    static let maxDirectoryEntries = 50000

    let url: URL
    let archive: Archive
    /// Indexed entries in central-directory order.
    let entries: [Entry]
    private let entriesByPath: [String: Entry]

    init(url: URL) throws {
        self.url = url
        archive = try Archive(url: url, accessMode: .read)
        var ordered: [Entry] = []
        var byPath: [String: Entry] = [:]
        for entry in archive {
            if ordered.count >= Self.maxDirectoryEntries {
                break
            }
            ordered.append(entry)
            // ZIP allows duplicate paths; match `Archive.subscript`, which returns the first.
            if byPath[entry.path] == nil {
                byPath[entry.path] = entry
            }
        }
        entries = ordered
        entriesByPath = byPath
    }

    func entry(_ path: String) -> Entry? {
        entriesByPath[path]
    }
}
