import Foundation

public enum YouTrackError: Error, CustomStringConvertible {
    case unexpectedResponse(String)
    case curlFailed(String)

    public var description: String {
        switch self {
        case .unexpectedResponse(let body): "Unexpected YouTrack response: \(body)"
        case .curlFailed(let message): "curl fallback failed: \(message)"
        }
    }
}

/// Files competitions the user decides to enter as YouTrack issues (the Track
/// button sink). Mirrors job-recon's youtrack.py invariant: Type is set in the
/// same POST that creates the issue, so a transient failure can never leave a
/// default-typed orphan.
public struct YouTrackClient: Sendable {
    public let config: YouTrackConfig

    public init?(config: YouTrackConfig? = SecretsReader.youTrackConfig()) {
        guard let config else { return nil }
        self.config = config
    }

    public func issueURL(_ idReadable: String) -> URL? {
        URL(string: "\(config.baseURL)/issue/\(idReadable)")
    }

    /// Creates a Task issue and returns its readable id (e.g. COMP-12).
    public func createIssue(
        project: String = "COMP", summary: String, description: String
    ) async throws -> String {
        let body: [String: Any] = [
            "project": ["shortName": project],
            "summary": summary,
            "description": description,
            "customFields": [[
                "name": "Type",
                "$type": "SingleEnumIssueCustomField",
                "value": ["name": "Task"],
            ]],
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let url = URL(string: "\(config.baseURL)/api/issues?fields=idReadable")!
        let data = try await send(url: url, body: bodyData)
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let idReadable = object["idReadable"] as? String
        else {
            throw YouTrackError.unexpectedResponse(String(data: data, encoding: .utf8) ?? "<binary>")
        }
        return idReadable
    }

    private func send(url: URL, body: Data) async throws -> Data {
        do {
            return try await HTTP.post(url, headers: authHeaders, body: body)
        } catch HTTPError.badStatus(let code, _) where code == 403 {
            // The instance sits behind Cloudflare that 1010-blocks some
            // non-browser HTTP clients. curl is known to pass (job-recon
            // precedent), so retry through it.
            return try await postViaCurl(url: url, body: body)
        }
    }

    private var authHeaders: [String: String] {
        [
            "Authorization": "Bearer \(config.token)",
            "Content-Type": "application/json",
            "Accept": "application/json",
        ]
    }

    private func postViaCurl(url: URL, body: Data) async throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        process.arguments = [
            "-sS", "--fail-with-body", "-X", "POST",
            "-H", "Authorization: Bearer \(config.token)",
            "-H", "Content-Type: application/json",
            "-H", "Accept: application/json",
            "--data-binary", "@-",
            url.absoluteString,
        ]
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { finished in
                let out = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let err = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                if finished.terminationStatus == 0 {
                    continuation.resume(returning: out)
                } else {
                    let message = String(data: err.isEmpty ? out : err, encoding: .utf8) ?? ""
                    continuation.resume(throwing: YouTrackError.curlFailed(message))
                }
            }
            do {
                try process.run()
                stdinPipe.fileHandleForWriting.write(body)
                try? stdinPipe.fileHandleForWriting.close()
            } catch {
                process.terminationHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }
}
