/// Centralized SQL statement definitions. All SQL lives here — no inline SQL elsewhere.
enum SQLStatements {
    // MARK: - Schema

    static let createSchemaMigrationsTable = """
        CREATE TABLE IF NOT EXISTS schema_migrations (
            version INTEGER PRIMARY KEY,
            applied_at TEXT NOT NULL
        );
        """

    static let createFilesTable = """
        CREATE TABLE IF NOT EXISTS files (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            path TEXT NOT NULL UNIQUE,
            filename TEXT NOT NULL,
            ext TEXT NOT NULL,
            size INTEGER NOT NULL,
            modified_date TEXT NOT NULL
        );
        """

    static let createFilesPathIndex = """
        CREATE INDEX IF NOT EXISTS idx_files_path ON files(path);
        """

    static let createFilesExtIndex = """
        CREATE INDEX IF NOT EXISTS idx_files_ext ON files(ext);
        """

    static let createFilesFilenameIndex = """
        CREATE INDEX IF NOT EXISTS idx_files_filename ON files(filename);
        """

    // MARK: - Migrations

    static let selectAppliedMigrationVersions = """
        SELECT version FROM schema_migrations ORDER BY version;
        """

    static let insertMigration = """
        INSERT INTO schema_migrations (version, applied_at) VALUES (?, ?);
        """

    // MARK: - Files CRUD

    static let insertFile = """
        INSERT INTO files (path, filename, ext, size, modified_date)
        VALUES (?, ?, ?, ?, ?);
        """

    static let upsertFile = """
        INSERT INTO files (path, filename, ext, size, modified_date)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(path) DO UPDATE SET
            filename = excluded.filename,
            ext = excluded.ext,
            size = excluded.size,
            modified_date = excluded.modified_date;
        """

    static let updateFile = """
        UPDATE files
        SET path = ?, filename = ?, ext = ?, size = ?, modified_date = ?
        WHERE id = ?;
        """

    static let deleteFile = """
        DELETE FROM files WHERE id = ?;
        """

    static let selectFilesBase = """
        SELECT id, path, filename, ext, size, modified_date
        FROM files
        WHERE 1 = 1
        """

    // MARK: - Transactions

    static let beginTransaction = "BEGIN IMMEDIATE TRANSACTION;"
    static let commitTransaction = "COMMIT;"
    static let rollbackTransaction = "ROLLBACK;"
}
