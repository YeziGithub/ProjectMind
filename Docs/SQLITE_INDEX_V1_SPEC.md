# SQLite Index v1 Spec

## 1. Goal

SQLite Index v1 establishes the first end-to-end file-level index for ProjectMind.

The goal is to connect the already implemented Scanner and Database layers through a minimal CLI workflow:

- Build a project file-level index.
- Connect Scanner output (`ProjectFile`) to SQLite persistence.
- Create a stable foundation for later Parser and Symbol Index work.
- Keep the pipeline deterministic and local-first.
- Preserve the current Clean Architecture boundaries.

SQLite Index v1 does not parse source code. It does not create a graph, does not summarize code, and does not call any LLM. Its success condition is simple: given a project path, ProjectMind can scan project files, persist file metadata to SQLite, and report a clear result.

## 2. Non-Goals

SQLite Index v1 does not include:

- AST parsing
- `SourceSymbol` persistence
- `ImportReference` persistence
- Call Graph
- Dependency Graph
- Embedding
- LLM
- Agent
- MCP
- Chat UI
- Parser implementation
- Graph implementation
- Multi-language indexing
- Remote index sync

## 3. Current Code Baseline

Current available capabilities:

- Core already defines `Project`, `ProjectFile`, `StoredFile`, and `FileQuery`.
- Core already defines `ScannerProtocol` and `DatabaseProtocol`.
- Scanner can stream `ProjectFile` values through `SwiftProjectScanner` and `ProjectFileSequence`.
- Scanner already filters common ignored directories such as `.git`, `.build`, `Pods`, `DerivedData`, `Carthage`, and `.swiftpm`.
- Database can open SQLite, run migrations, insert / update / delete / query `ProjectFile` metadata through `SQLiteDatabase`.
- Database currently persists only file-level metadata in the `files` table.
- CLI currently contains command parsing and command dispatch skeleton only.
- Parser, Git, and Query modules currently remain stubs.
- CI runs `swift build` and `swift test` on `macos-latest`.

Current important limitation:

- There is no implemented CLI pipeline connecting `scan` to Scanner and Database.
- There is no Project table in the current SQLite schema.
- There is no upsert API yet for repeated scans.

## 4. User-Facing CLI Behavior

Recommended initial command:

```bash
projectmind scan /path/to/project
```

Expected output:

```text
ProjectMind scan complete
project: /path/to/project
scanned files: 123
indexed files: 123
database: /path/to/project/.projectmind/projectmind.sqlite
elapsed: 0.42s
```

Expected invalid path behavior:

```text
Error: invalid project path: /bad/path
```

Recommended parameters for v1:

- `--db path`: yes. Useful for CI, tests, and users who do not want `.projectmind` in the project directory.
- `--verbose`: not required in v1. It can be added later when skipped-file reporting and per-directory diagnostics exist.
- `--dry-run`: not required in v1. Scanner already has tests for scanning behavior; v1 should focus on the indexing loop.

Recommended v1 CLI forms:

```bash
projectmind scan /path/to/project
projectmind scan /path/to/project --db /tmp/projectmind.sqlite
```

Default database path:

```text
<project-root>/.projectmind/projectmind.sqlite
```

Rationale:

- It is local-first.
- It is easy to find and delete.
- It does not require global user configuration.
- It keeps the index near the project it describes.

## 5. Architecture Design

Recommended connection:

```text
ProjectMindCLI
  -> ScanProjectUseCase / Application Service
    -> ScannerProtocol
    -> DatabaseProtocol
    -> SQLiteDatabase
```

Rules:

- Do not put the scan/index loop directly in `ProjectMindCLI.main()`.
- Do not make Scanner depend on Database.
- Do not make Database depend on Scanner.
- Do not make Core depend on outer modules.
- Keep CLI as the composition root: parse arguments, create concrete adapters, call one use case, print result.

UseCase placement recommendation:

- Add a lightweight use case in Core only if it depends only on Core protocols and Core entities.
- A suitable name would be `ScanProjectIndexUseCase` or `BuildFileIndexUseCase`.
- Its dependencies should be protocol-typed:
  - `any ScannerProtocol` is difficult because `ScannerProtocol` has an associated type.
  - Prefer a concrete generic use case over type erasure, or introduce a small Core protocol that returns an erased async sequence only if necessary.

Pragmatic v1 option:

- Keep the use case in `ProjectMindCLI` as an internal application service if avoiding Core generic complexity is preferred.
- This is acceptable for v1 if the service remains small and only coordinates Scanner and Database through their public APIs.
- Do not create a large new module for v1.

## 6. Data Flow

1. CLI receives project path and optional `--db`.
2. CLI normalizes the project path as a file URL.
3. CLI / use case validates that the path exists and is a directory.
4. CLI / use case creates project metadata in memory.
5. CLI creates `SwiftProjectScanner`.
6. CLI creates `SQLiteDatabase`.
7. Database opens the target SQLite path.
8. Database runs `createTables()` / migrations.
9. Scanner streams `ProjectFile` values.
10. For each `ProjectFile`, Database writes file metadata.
11. Use case counts scanned and indexed files.
12. Database closes.
13. CLI prints project path, scanned count, indexed count, database path, and elapsed time.

Error handling:

- Invalid path should produce a clear message and non-zero exit code.
- Database open / migration / write errors should include database path and underlying error.
- Scanner errors should include project path.

## 7. Database Scope

SQLite Index v1 should write only file-level data.

Current schema:

- `schema_migrations`
- `files`

Current file fields:

- `path`
- `filename`
- `ext`
- `size`
- `modified_date`

Question: should v1 add a `projects` table?

Option 1: files only

- Minimal.
- Uses current schema and current tests.
- Enough to prove Scanner -> Database -> CLI.
- Cannot store project root or scan metadata.

Option 2: add `projects` table

- Better represents Core `Project`.
- Enables future project metadata queries.
- Requires migration v2 and tests.
- Slightly expands v1 scope.

Recommendation:

- SQLite Index v1 should start with files-only unless the owner explicitly wants project metadata persisted immediately.
- The CLI can still create a `Project` value in memory for reporting.
- Add `projects` as a near-term follow-up when Query or multi-project indexing begins.

Do not add these tables in v1:

- `source_files`
- `source_symbols`
- `import_references`
- `call_edges`
- `dependency_edges`
- `embeddings`

Future Work:

- Symbol Index can add `source_files`, `symbols`, and `imports` after Parser produces real `SourceFile` data.

## 8. Testing Plan

Add or update tests for:

- CLI scan argument parsing.
- CLI scan invalid path handling.
- Scanner + Database integration.
- Database write then query after scan.
- Empty project directory.
- Excluded directories are not written to Database.
- Repeated scan behavior.
- Upsert behavior if upsert is added.
- Custom `--db` path.
- Default database path calculation.
- Database close / cleanup on success.
- Database close / cleanup on failure.

Recommended test layout:

- Keep unit tests in existing module test targets.
- Add CLI behavior tests under `Tests/ProjectMindCLITests`.
- Add Database persistence tests under `Tests/DatabaseTests`.
- Add a focused integration test if CLI can be exercised without spawning a process.

Avoid:

- Shelling out to `swift run` for every test.
- Depending on global user directories.
- Reusing a persistent SQLite file across tests.

## 9. Implementation Plan

### Step 1: CLI scan command parsing

Goal:

- Parse `projectmind scan <path>`.
- Parse optional `--db <path>`.
- Return a structured command instead of only `CLICommand.scan`.

Expected files:

- `Sources/ProjectMindCLI/CommandParser.swift`
- `Tests/ProjectMindCLITests`

Notes:

- Keep parsing simple.
- Do not implement `parse`, `index`, `query`, or `git` behavior yet.

### Step 2: Add minimal scan application service

Goal:

- Coordinate Scanner and Database without putting business logic in `main()`.

Expected files:

- `Sources/ProjectMindCLI/ScanCommandRunner.swift` or similar
- Possibly Core protocol/use case files only if the design stays clean and small

Dependencies:

- `ScannerProtocol`
- `DatabaseProtocol`
- `ProjectFile`
- `FileQuery`

Note:

- Because `ScannerProtocol` has an associated type, a generic runner may be simpler than existential type erasure.

### Step 3: Scanner to Database write

Goal:

- Open database.
- Run migrations.
- Iterate scanner output.
- Persist each `ProjectFile`.
- Track scanned and indexed counts.

Expected files:

- `Sources/ProjectMindCLI/ScanCommandRunner.swift`
- `Sources/Database/SQLiteDatabase.swift`
- `Sources/Database/SQLite/SQLiteExecutor.swift`
- `Sources/Database/SQL/SQLStatements.swift`
- `Tests/DatabaseTests/SQLiteDatabaseTests.swift`

Important design choice:

- Current `insertFile` fails on duplicate path.
- Repeated scan requires either:
  - a new upsert method, or
  - query then update/insert behavior in the runner.

Recommendation:

- Add an explicit `upsertFile` API in DatabaseProtocol only if repeated scan is required in v1.
- If avoiding protocol changes, document that repeated scan is not guaranteed until v1.1.

### Step 4: Test coverage

Goal:

- Prove file-level indexing works.

Expected tests:

- CLI parser tests for scan path and `--db`.
- Integration-style test that scans `Tests/ScannerTests/Fixtures/SampleProject` into a temp database.
- Query database and assert only expected file rows exist.
- Repeated scan behavior test if upsert is implemented.

Expected files:

- `Tests/ProjectMindCLITests`
- `Tests/DatabaseTests`
- Possibly `Tests/ScannerTests`

### Step 5: CI verification

Run:

```bash
swift build
swift test
```

Expected result:

- Both pass in GitHub Actions on `macos-latest`.

## 10. Risk Analysis

CLI depends on too many modules:

- Risk: CLI becomes a large procedural script.
- Mitigation: keep CLI as composition root and move orchestration into a small runner/use case.

UseCase placement:

- Risk: putting use cases in Core may introduce generic complexity due to `ScannerProtocol` associated type.
- Mitigation: start with a small internal CLI runner or a generic Core use case.

Database schema migration:

- Risk: adding `projects` too early causes schema churn.
- Mitigation: v1 files-only, project metadata later.

Large project scanning:

- Risk: scanning very large repositories may need cancellation and batching.
- Mitigation: stream files and add cancellation checks later.

File path normalization:

- Risk: duplicate paths if different path spellings point to the same file.
- Mitigation: use standardized file URLs consistently before persistence.

Repeated scan:

- Risk: current unique path constraint causes duplicate insert errors.
- Mitigation: define v1 repeated scan behavior before implementation.

Default database path:

- Risk: writing `.projectmind` into read-only projects can fail.
- Mitigation: support `--db` path in v1.

Database close and resource release:

- Risk: early errors leave database open.
- Mitigation: centralize cleanup in runner with explicit do/catch close.

Error clarity:

- Risk: low-level SQLite errors leak without context.
- Mitigation: CLI should map known `ProjectMindError` cases to clear messages.

## 11. Open Questions

- Should the default database path be `<project-root>/.projectmind/projectmind.sqlite`?
- Should `scan` create `.projectmind` automatically?
- Should `scan` default to overwriting old file rows, upserting, or failing on duplicates?
- Is `--db path` required in v1?
- Is `--dry-run` required in v1?
- Is `--verbose` required in v1?
- Should v1 report skipped files or only indexed files?
- Should v1 persist `Project` metadata now or only file rows?
- Should database paths be absolute in output?
- Should scan include non-Swift files later, or remain Swift-focused in v1?

## 12. Recommended Implementation Choice

Recommended choice: B.打通 CLI scan 到 Scanner + Database 文件级索引

Reason:

- Parser is still a stub, so SourceSymbol Index is premature.
- Scanner already emits `ProjectFile`.
- Database already persists `ProjectFile` metadata.
- A file-level CLI scan creates the first useful end-to-end ProjectMind workflow.
- It validates the architecture without expanding into Parser, Graph, LLM, or MCP.

Not recommended:

- A. Scanner-only CLI scan is too shallow because it does not exercise the persistence layer.
- C. SourceSymbol Index requires Parser output that does not exist yet.

## 13. Files Expected to Change in Future Implementation

Likely files:

- `Package.swift`
- `Sources/ProjectMindCLI/ProjectMindCLI.swift`
- `Sources/ProjectMindCLI/CommandParser.swift`
- `Sources/ProjectMindCLI/ScanCommandRunner.swift` or equivalent new small runner
- `Sources/Core/Protocols/DatabaseProtocol.swift`
- `Sources/Database/SQLiteDatabase.swift`
- `Sources/Database/SQLite/SQLiteExecutor.swift`
- `Sources/Database/SQL/SQLStatements.swift`
- `Tests/ProjectMindCLITests`
- `Tests/DatabaseTests/SQLiteDatabaseTests.swift`

Possible files:

- `Sources/Core/Entities/Project.swift`
- `Sources/Core/Entities/FileQuery.swift`
- `Tests/ScannerTests`

Avoid changing in v1 unless necessary:

- Parser implementations
- Query implementation
- Git implementation
- Any Graph-related files
- Any LLM / Embedding / MCP / Agent files

## 14. Final Recommendation

下一步应该先做 SQLite Index v1 的文件级 CLI scan 闭环，因为 Scanner 和 Database 已有基础能力，而 Parser 还未实现，文件级索引是最小、确定、可验证的 ProjectMind 端到端价值。
