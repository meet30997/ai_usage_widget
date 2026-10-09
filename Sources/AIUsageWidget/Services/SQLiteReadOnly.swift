import Foundation
import SQLite3

enum SQLiteReadOnly {
    /// Opens a database we must never write to. Antigravity and Codex keep
    /// their databases in WAL mode; when the owning app isn't running the
    /// `-shm` file is gone, and a read-only connection can't recreate it,
    /// so a plain SQLITE_OPEN_READONLY fails with SQLITE_CANTOPEN. In that
    /// case fall back to `immutable=1`, which reads the main file without
    /// locking or shm. A missing -shm means the owner isn't running, so at
    /// worst we miss a few uncheckpointed turns until it next opens.
    static func open(_ url: URL) -> OpaquePointer? {
        func canRead(_ db: OpaquePointer) -> Bool {
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            return sqlite3_prepare_v2(db, "SELECT 1 FROM sqlite_master LIMIT 1", -1, &statement, nil) == SQLITE_OK
                && sqlite3_step(statement) != SQLITE_ERROR
        }

        var db: OpaquePointer?
        if sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
           let db, canRead(db) {
            return db
        }
        sqlite3_close(db)
        db = nil

        var components = URLComponents()
        components.scheme = "file"
        components.path = url.path
        components.queryItems = [URLQueryItem(name: "immutable", value: "1")]
        guard let uri = components.string,
              sqlite3_open_v2(uri, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let db, canRead(db) else {
            sqlite3_close(db)
            return nil
        }
        return db
    }
}
