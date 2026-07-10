import Foundation

public enum HTTPError: Error, CustomStringConvertible {
    case badStatus(code: Int, url: String)

    public var description: String {
        switch self {
        case .badStatus(let code, let url): "HTTP \(code) from \(url)"
        }
    }
}

/// Thin URLSession wrapper. Several sources (CTFtime, ybox) reject default
/// library user agents, so every request goes out with a browser-like UA.
public enum HTTP {
    public static let browserUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
        + "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"

    public static func get(_ url: URL, headers: [String: String] = [:]) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue(browserUserAgent, forHTTPHeaderField: "User-Agent")
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(code) else {
            throw HTTPError.badStatus(code: code, url: url.absoluteString)
        }
        return data
    }
}
