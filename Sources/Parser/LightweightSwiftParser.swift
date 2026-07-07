import Core
import Foundation

/// Lightweight Swift source parser used until a real AST parser is wired in.
public struct LightweightSwiftParser: ParserProtocol, Sendable {
    public let kind: ParserKind = .swiftSyntax

    public init() {}

    public func parse(file: ProjectFile) async throws -> SourceFile {
        guard file.ext == "swift" else {
            return SourceFile(file: file)
        }

        let url = URL(fileURLWithPath: file.path)
        let contents: String
        do {
            contents = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw ProjectMindError.parseFailed(path: file.path, underlying: "\(error)")
        }

        var symbols: [SourceSymbol] = []
        var imports: [ImportReference] = []
        var occurrence = 0

        for (lineIndex, rawLine) in contents.components(separatedBy: .newlines).enumerated() {
            let lineNumber = lineIndex + 1
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  !trimmed.hasPrefix("//"),
                  !trimmed.hasPrefix("/*"),
                  !trimmed.hasPrefix("*")
            else {
                continue
            }

            if let importReference = parseImport(
                line: rawLine,
                trimmed: trimmed,
                lineNumber: lineNumber,
                filePath: file.path,
                occurrence: occurrence
            ) {
                imports.append(importReference)
                occurrence += 1
                continue
            }

            if let symbol = parseSymbol(
                line: rawLine,
                trimmed: trimmed,
                lineNumber: lineNumber,
                filePath: file.path,
                occurrence: occurrence
            ) {
                symbols.append(symbol)
                occurrence += 1
            }
        }

        return SourceFile(file: file, symbols: symbols, imports: imports)
    }

    private func parseImport(
        line: String,
        trimmed: String,
        lineNumber: Int,
        filePath: String,
        occurrence: Int
    ) -> ImportReference? {
        guard trimmed.hasPrefix("import ") else { return nil }
        let parts = trimmed.split(whereSeparator: { $0 == " " || $0 == "\t" })
        guard let module = parts.dropFirst().first else { return nil }
        let moduleName = String(module).split(separator: ".").first.map(String.init) ?? String(module)
        let column = column(of: "import", in: line)

        return ImportReference(
            id: "\(filePath):import:\(lineNumber):\(column):\(occurrence)",
            moduleName: moduleName,
            filePath: filePath,
            location: SourceLocation(
                line: lineNumber,
                column: column,
                endLine: lineNumber,
                endColumn: column + trimmed.count
            )
        )
    }

    private func parseSymbol(
        line: String,
        trimmed: String,
        lineNumber: Int,
        filePath: String,
        occurrence: Int
    ) -> SourceSymbol? {
        let accessLevel = leadingAccessLevel(in: trimmed)
        let tokens = declarationTokens(from: trimmed)
        guard let declaration = declaration(in: tokens) else { return nil }

        let kind = declaration.kind
        let name = cleanName(declaration.name)
        guard !name.isEmpty else { return nil }

        let keyword = declaration.keyword
        let column = column(of: keyword, in: line)
        let signature = signatureText(from: trimmed)

        return SourceSymbol(
            id: "\(filePath):symbol:\(lineNumber):\(column):\(kind.rawValue):\(name):\(occurrence)",
            name: name,
            kind: kind,
            filePath: filePath,
            location: SourceLocation(
                line: lineNumber,
                column: column,
                endLine: lineNumber,
                endColumn: column + signature.count
            ),
            accessLevel: accessLevel,
            parentName: nil,
            signature: signature
        )
    }

    private func declarationTokens(from line: String) -> [String] {
        let stripped = line
            .replacingOccurrences(of: "(", with: " ")
            .replacingOccurrences(of: ":", with: " ")
            .replacingOccurrences(of: "{", with: " ")
            .replacingOccurrences(of: "=", with: " ")
        return stripped.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
    }

    private func declaration(in tokens: [String]) -> (keyword: String, kind: SymbolKind, name: String)? {
        let mappings: [(String, SymbolKind)] = [
            ("struct", .struct),
            ("class", .class),
            ("enum", .enum),
            ("protocol", .protocol),
            ("actor", .actor),
            ("extension", .extension),
            ("func", .function),
            ("var", .property),
            ("let", .property),
        ]

        for (keyword, kind) in mappings {
            guard let index = tokens.firstIndex(of: keyword),
                  tokens.indices.contains(index + 1)
            else {
                continue
            }
            return (keyword, kind, tokens[index + 1])
        }

        return nil
    }

    private func cleanName(_ name: String) -> String {
        name.trimmingCharacters(in: CharacterSet(charactersIn: ",(){}[]<>"))
    }

    private func leadingAccessLevel(in line: String) -> String? {
        let accessLevels = ["public", "private", "fileprivate", "internal", "open"]
        return accessLevels.first { line.hasPrefix("\($0) ") }
    }

    private func signatureText(from line: String) -> String {
        if let commentRange = line.range(of: "//") {
            return String(line[..<commentRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        return line.trimmingCharacters(in: .whitespaces)
    }

    private func column(of needle: String, in line: String) -> Int {
        guard let range = line.range(of: needle) else { return 1 }
        return line.distance(from: line.startIndex, to: range.lowerBound) + 1
    }
}
