//
//  GzipLineReader.swift
//  k-cal
//
//  Reads a gzip file a line at a time. Daily food updates unpack to well over 100 MB, so nothing here holds
//  more than a chunk of the file and the current line in memory.
//

import Foundation
import zlib

enum GzipLineReader {
    enum Failure: Error {
        case corrupt
    }

    private static let chunkSize = 1 << 20
    /// Tells zlib to expect a gzip header, with the largest window.
    private static let gzipWindowBits: Int32 = 15 + 16

    /// Calls `body` with each line. Files may hold several gzip members, one after another.
    static func forEachLine(in url: URL, _ body: (Data) throws -> Void) throws {
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }

        var stream = z_stream()
        guard inflateInit2_(&stream, gzipWindowBits, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            throw Failure.corrupt
        }
        defer { inflateEnd(&stream) }

        let output = UnsafeMutablePointer<UInt8>.allocate(capacity: chunkSize)
        defer { output.deallocate() }

        var line = Data()
        var memberEnded = false

        while let chunk = try file.read(upToCount: chunkSize), !chunk.isEmpty {
            try chunk.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
                stream.next_in = UnsafeMutablePointer(mutating: bytes.bindMemory(to: UInt8.self).baseAddress)
                stream.avail_in = UInt32(bytes.count)
                repeat {
                    stream.next_out = output
                    stream.avail_out = UInt32(chunkSize)
                    let status = inflate(&stream, Z_NO_FLUSH)
                    guard status == Z_OK || status == Z_STREAM_END || status == Z_BUF_ERROR else {
                        throw Failure.corrupt
                    }
                    let produced = UnsafeBufferPointer(start: output, count: chunkSize - Int(stream.avail_out))
                    try autoreleasepool {
                        var rest = produced[...]
                        while let newline = rest.firstIndex(of: 10) {
                            line.append(contentsOf: rest[..<newline])
                            try body(line)
                            line.removeAll(keepingCapacity: true)
                            rest = rest[(newline + 1)...]
                        }
                        line.append(contentsOf: rest)
                    }
                    memberEnded = status == Z_STREAM_END
                    if memberEnded {
                        inflateReset(&stream)
                    }
                } while stream.avail_in > 0 || stream.avail_out == 0
            }
        }
        // A file cut off part way through never reaches the end of its last member.
        guard memberEnded else { throw Failure.corrupt }
        if !line.isEmpty { try body(line) }
    }
}
