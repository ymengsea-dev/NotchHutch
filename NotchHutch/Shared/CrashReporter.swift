import Foundation

/// Minimal local crash logger: writes uncaught exceptions and fatal signals
/// to ~/Library/Logs/Notch Hutch/ so users can attach them to bug reports.
/// No network, no dependencies.
///
/// Known limitation (accepted): the signal handler uses Foundation APIs that
/// are not strictly async-signal-safe. Worst case the log write fails during
/// a hard crash; it cannot make the crash worse.
enum CrashReporter {

    private static let logDirectory: URL = {
        let dir = FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/Notch Hutch", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static func install() {
        NSSetUncaughtExceptionHandler { exception in
            let report = """
            Notch Hutch crash report
            Date: \(Date())
            Type: uncaught exception
            Name: \(exception.name.rawValue)
            Reason: \(exception.reason ?? "unknown")

            Call stack:
            \(exception.callStackSymbols.joined(separator: "\n"))
            """
            CrashReporter.write(report)
        }

        for sig in [SIGABRT, SIGSEGV, SIGBUS, SIGILL, SIGFPE, SIGTRAP] {
            signal(sig) { sig in
                let report = """
                Notch Hutch crash report
                Date: \(Date())
                Type: fatal signal \(sig)

                Call stack:
                \(Thread.callStackSymbols.joined(separator: "\n"))
                """
                CrashReporter.write(report)
                // Restore default handling and re-raise so the OS still
                // produces its own crash report.
                signal(sig, SIG_DFL)
                raise(sig)
            }
        }
    }

    private static func write(_ report: String) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime]
        let stamp = formatter.string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let file = logDirectory.appendingPathComponent("crash-\(stamp).log")
        try? report.write(to: file, atomically: true, encoding: .utf8)
    }
}
