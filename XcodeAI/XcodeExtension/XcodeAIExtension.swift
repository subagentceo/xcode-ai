// XcodeAIExtension.swift — all commands + WorkersAI client
// Xcode 26 Source Editor Extension
// Connects to coworkers-agent Worker via URLSession (no Anthropic key)

import Foundation
import XcodeKit

class SourceEditorExtension: NSObject, XCSourceEditorExtension {
    var commandDefinitions: [[XCSourceEditorCommandDefinitionKey: Any]] {
        [("ExplainCodeCommand",      "explain",  "Explain Selected Code"),
         ("RefactorCodeCommand",     "refactor", "Refactor Selected Code"),
         ("GenerateTestsCommand",    "tests",    "Generate Unit Tests"),
         ("FixBugCommand",           "fix",      "Fix Bug / Suggest Fix"),
         ("DocumentCodeCommand",     "document", "Add Documentation Comments"),
         ("ReviewCodeCommand",       "review",   "Code Review (Inline Comments)"),
         ("TranslateToSwiftCommand", "toswift",  "Translate to Swift 6")].map {
            [.classNameKey: "XcodeAI.\($0.0)", .identifierKey: "com.managedcoworkers.xcode.\($0.1)", .nameKey: $0.2]
         }
    }
}

struct XcodeAISession {
    let email: String; let ts: TimeInterval
    var isExpired: Bool { Date().timeIntervalSince1970 - ts > 86400 }
    var token: String { Data("{\"email\":\"\"\(email)\"\":\"ts\":\(ts)}".utf8).base64EncodedString() }
    static func load() -> XcodeAISession? {
        let d = UserDefaults(suiteName: "group.com.managedcoworkers.native")
        guard let e = d?.string(forKey: "email"), let t = d?.double(forKey: "sessionTs") else { return nil }
        let s = XcodeAISession(email: e, ts: t); return s.isExpired ? nil : s
    }
}

final class WorkersAIClient {
    static let shared = WorkersAIClient()
    private let base = URL(string: "https://agentknowledgeworkers.com")!
    func query(command: String, code: String, language: String) async throws -> String {
        guard let sess = XcodeAISession.load() else { throw XcodeAIError.notAuthenticated }
        let prompts: [String: String] = [
            "explain":  "Explain this \(language) code concisely. One sentence summary then key points:\n```\n\(code)\n```",
            "refactor": "Refactor this \(language) code. Return ONLY the improved code:\n```\n\(code)\n```",
            "tests":    "Write XCTest unit tests for this \(language) code. Return ONLY test code:\n```\n\(code)\n```",
            "fix":      "Find and fix bugs in this \(language) code. Explain fixes then show corrected code:\n```\n\(code)\n```",
            "document": "Add /// documentation to this \(language) code. Return ONLY documented code:\n```\n\(code)\n```",
            "review":   "Review this \(language) code. Add // AI: inline comments for issues:\n```\n\(code)\n```",
            "toswift":  "Convert to Swift 6 with strict concurrency. Return ONLY Swift code:\n```\n\(code)\n```",
        ]
        struct Body: Encodable { let message, plugin: String }
        var req = URLRequest(url: base.appending(path: "/api/chat"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("s=\(sess.token)", forHTTPHeaderField: "Cookie")
        req.timeoutInterval = 60
        req.httpBody = try JSONEncoder().encode(Body(message: prompts[command] ?? code, plugin: "engineering"))
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw XcodeAIError.http((resp as? HTTPURLResponse)?.statusCode ?? 0) }
        struct R: Decodable { struct M: Decodable { let content: String }; let message: M }
        return (try? JSONDecoder().decode(R.self, from: data))?.message.content ?? "[no response]"
    }
}

enum XcodeAIError: LocalizedError {
    case notAuthenticated, noSelection, http(Int)
    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Sign in to CoworkersNative iOS app first"
        case .noSelection:      return "Select code before running an XcodeAI command"
        case .http(let c):      return "API error HTTP \(c)"
        }
    }
}

class BaseAICommand: NSObject, XCSourceEditorCommand {
    var commandName: String { "explain" }
    func perform(with inv: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void) {
        Task {
            do {
                guard let sels = inv.buffer.selections as? [XCSourceTextRange], !sels.isEmpty else { completionHandler(XcodeAIError.noSelection); return }
                let sel = sels[0]
                let lines = inv.buffer.lines as! [String]
                let code = lines[sel.start.line...min(sel.end.line, lines.count-1)].joined()
                let lang = inv.buffer.contentUTI.contains("swift") ? "Swift" : ""
                let result = try await WorkersAIClient.shared.query(command: commandName, code: code, language: lang)
                await MainActor.run {
                    let ls = inv.buffer.lines as! NSMutableArray
                    let indent = String((ls[sel.start.line] as! String).prefix(while: { $0 == " " || $0 == "\t" }))
                    let pfx = lang == "Swift" ? "///" : "//"
                    var block = ["\(indent)\(pfx) ── XcodeAI: \(commandName) ──\n"]
                    result.components(separatedBy: "\n").forEach { block.append("\(indent)\(pfx) \($0)\n") }
                    block.enumerated().forEach { ls.insert($1, at: sel.start.line + $0) }
                }
                completionHandler(nil)
            } catch { completionHandler(error) }
        }
    }
}

class ExplainCodeCommand:     BaseAICommand { override var commandName: String { "explain" } }
class RefactorCodeCommand:    BaseAICommand { override var commandName: String { "refactor" } }
class GenerateTestsCommand:   BaseAICommand { override var commandName: String { "tests" } }
class FixBugCommand:          BaseAICommand { override var commandName: String { "fix" } }
class DocumentCodeCommand:    BaseAICommand { override var commandName: String { "document" } }
class ReviewCodeCommand:      BaseAICommand { override var commandName: String { "review" } }
class TranslateToSwiftCommand: BaseAICommand { override var commandName: String { "toswift" } }