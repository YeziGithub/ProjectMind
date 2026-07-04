import Foundation
import Core
import Scanner
import Testing

@Suite("ScannerProtocol")
struct ScannerProtocolTests {
    @Test("SwiftProjectScanner conforms to ScannerProtocol")
    func conforms() {
        let scanner: any ScannerProtocol = SwiftProjectScanner()
        _ = scanner
    }
}
