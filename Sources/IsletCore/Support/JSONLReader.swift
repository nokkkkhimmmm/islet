import Foundation

/// Incremental line reader for append-only JSONL transcripts.
///
/// Agent transcripts grow continuously while a session runs and can reach tens of megabytes.
/// Re-reading a whole file on every poll would be wasteful, so we remember how far we read and
/// only consume bytes appended since then. Partial trailing lines (the agent was mid-write when
/// we looked) are deliberately left unconsumed and picked up on the next pass.
public enum JSONLReader {
    public struct Chunk {
        public let objects: [JSONObject]
        /// Byte offset just past the last *complete* line consumed.
        public let newOffset: UInt64
    }

    /// Reads whole lines from `url` starting at `offset`.
    ///
    /// If the file has shrunk below `offset` it is treated as rewritten and read from the start.
    public static func read(url: URL, from offset: UInt64) throws -> Chunk {
        let size = try fileSize(of: url)
        var start = offset
        if size < offset {
            start = 0  // File was truncated or replaced; resync from the beginning.
        }
        guard size > start else {
            return Chunk(objects: [], newOffset: start)
        }

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        try handle.seek(toOffset: start)
        guard let data = try handle.readToEnd(), !data.isEmpty else {
            return Chunk(objects: [], newOffset: start)
        }

        var objects: [JSONObject] = []
        var cursor = data.startIndex
        var lastCompleteLineEnd = data.startIndex

        while cursor < data.endIndex,
              let newline = data[cursor...].firstIndex(of: 0x0A) {
            let line = data[cursor..<newline]
            if !line.isEmpty, let object = JSONObject(data: Data(line)) {
                objects.append(object)
            }
            cursor = data.index(after: newline)
            lastCompleteLineEnd = cursor
        }

        let consumed = lastCompleteLineEnd - data.startIndex
        return Chunk(objects: objects, newOffset: start + UInt64(consumed))
    }

    public static func fileSize(of url: URL) throws -> UInt64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.uint64Value ?? 0
    }

    public static func modificationDate(of url: URL) -> Date? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return attributes?[.modificationDate] as? Date
    }
}
