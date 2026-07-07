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

    static let createSourceFilesTable = """
        CREATE TABLE IF NOT EXISTS source_files (
            id TEXT PRIMARY KEY,
            file_path TEXT NOT NULL UNIQUE,
            parser_kind TEXT NOT NULL,
            parsed_at TEXT NOT NULL
        );
        """

    static let createSourceSymbolsTable = """
        CREATE TABLE IF NOT EXISTS source_symbols (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            kind TEXT NOT NULL,
            file_path TEXT NOT NULL,
            line INTEGER NOT NULL,
            column INTEGER NOT NULL,
            end_line INTEGER,
            end_column INTEGER,
            access_level TEXT,
            parent_name TEXT,
            signature TEXT
        );
        """

    static let createImportReferencesTable = """
        CREATE TABLE IF NOT EXISTS import_references (
            id TEXT PRIMARY KEY,
            module_name TEXT NOT NULL,
            file_path TEXT NOT NULL,
            line INTEGER NOT NULL,
            column INTEGER NOT NULL,
            end_line INTEGER,
            end_column INTEGER
        );
        """

    static let createSourceSymbolsNameIndex = """
        CREATE INDEX IF NOT EXISTS idx_source_symbols_name ON source_symbols(name);
        """

    static let createSourceSymbolsKindIndex = """
        CREATE INDEX IF NOT EXISTS idx_source_symbols_kind ON source_symbols(kind);
        """

    static let createSourceSymbolsFilePathIndex = """
        CREATE INDEX IF NOT EXISTS idx_source_symbols_file_path ON source_symbols(file_path);
        """

    static let createImportReferencesFilePathIndex = """
        CREATE INDEX IF NOT EXISTS idx_import_references_file_path ON import_references(file_path);
        """

    static let createImportReferencesModuleIndex = """
        CREATE INDEX IF NOT EXISTS idx_import_references_module ON import_references(module_name);
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

    // MARK: - Source index CRUD

    static let upsertSourceFile = """
        INSERT INTO source_files (id, file_path, parser_kind, parsed_at)
        VALUES (?, ?, ?, ?)
        ON CONFLICT(file_path) DO UPDATE SET
            id = excluded.id,
            parser_kind = excluded.parser_kind,
            parsed_at = excluded.parsed_at;
        """

    static let deleteSourceFileSymbols = """
        DELETE FROM source_symbols WHERE file_path = ?;
        """

    static let deleteSourceFileImports = """
        DELETE FROM import_references WHERE file_path = ?;
        """

    static let deleteSourceFile = """
        DELETE FROM source_files WHERE file_path = ?;
        """

    static let insertSourceSymbol = """
        INSERT INTO source_symbols (
            id, name, kind, file_path, line, column, end_line, end_column,
            access_level, parent_name, signature
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

    static let insertImportReference = """
        INSERT INTO import_references (
            id, module_name, file_path, line, column, end_line, end_column
        )
        VALUES (?, ?, ?, ?, ?, ?, ?);
        """

    static let selectSymbolsBase = """
        SELECT id, name, kind, file_path, line, column, end_line, end_column,
               access_level, parent_name, signature
        FROM source_symbols
        WHERE 1 = 1
        """

    static let selectImportsBase = """
        SELECT id, module_name, file_path, line, column, end_line, end_column
        FROM import_references
        WHERE 1 = 1
        """

    // MARK: - Transactions

    static let beginTransaction = "BEGIN IMMEDIATE TRANSACTION;"
    static let commitTransaction = "COMMIT;"
    static let rollbackTransaction = "ROLLBACK;"
}
