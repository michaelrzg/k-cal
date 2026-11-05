//
//  SQLite.swift
//  k-cal
//
//  A thin wrapper over the system SQLite library. Not thread-safe: each owner confines it to one actor.
//

import Foundation
import SQLite3

final class SQLite {
    enum Failure: Error {
        case message(String)
    }

    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    private var handle: OpaquePointer?

    /// Opens the database file. `immutable` is for files that never change, like one in the app bundle.
    init(url: URL, readOnly: Bool, immutable: Bool = false) throws {
        let path = immutable ? "\(url.absoluteString)?immutable=1" : url.path(percentEncoded: false)
        let flags = (readOnly ? SQLITE_OPEN_READONLY : SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
            | (immutable ? SQLITE_OPEN_URI : 0)
        guard sqlite3_open_v2(path, &handle, flags, nil) == SQLITE_OK else {
            defer { sqlite3_close(handle) }
            throw Failure.message(String(cString: sqlite3_errmsg(handle)))
        }
    }

    deinit {
        sqlite3_close(handle)
    }

    func execute(_ sql: String) throws {
        guard sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK else { throw failure }
    }

    func run(_ sql: String, _ values: [Any?] = []) throws {
        try query(sql, values) { _ in }
    }

    @discardableResult
    func query<Row>(_ sql: String, _ values: [Any?] = [], row: (OpaquePointer) -> Row) throws -> [Row] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else { throw failure }
        defer { sqlite3_finalize(statement) }
        for (index, value) in values.enumerated() {
            let position = Int32(index + 1)
            switch value {
            case let value as String: sqlite3_bind_text(statement, position, value, -1, Self.transient)
            case let value as Int: sqlite3_bind_int64(statement, position, Int64(value))
            default: sqlite3_bind_null(statement, position)
            }
        }
        var rows: [Row] = []
        while true {
            switch sqlite3_step(statement) {
            case SQLITE_ROW: rows.append(row(statement!))
            case SQLITE_DONE: return rows
            default: throw failure
            }
        }
    }

    func transaction(_ body: () throws -> Void) throws {
        try execute("BEGIN")
        do {
            try body()
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    private var failure: Failure {
        .message(String(cString: sqlite3_errmsg(handle)))
    }

    static func text(_ statement: OpaquePointer, _ column: Int32) -> String? {
        sqlite3_column_text(statement, column).map { String(cString: $0) }
    }

    static func integer(_ statement: OpaquePointer, _ column: Int32) -> Int? {
        sqlite3_column_type(statement, column) == SQLITE_NULL ? nil : Int(sqlite3_column_int64(statement, column))
    }
}
