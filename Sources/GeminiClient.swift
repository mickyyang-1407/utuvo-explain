import Foundation

struct GeminiClient {
    struct Request: Encodable {
        let systemInstruction: Content
        let contents: [Content]
        let generationConfig: GenerationConfig
    }

    struct Content: Codable {
        let role: String?
        let parts: [Part]
    }

    struct Part: Codable {
        let text: String?
    }

    struct GenerationConfig: Encodable {
        let temperature: Double
        let maxOutputTokens: Int
    }

    struct Response: Decodable {
        let candidates: [Candidate]?
        let error: APIError?
    }

    struct Candidate: Decodable {
        let content: Content?
    }

    struct APIError: Decodable {
        let code: Int?
        let message: String?
    }

    enum ClientError: LocalizedError {
        case invalidModel
        case server(Int, String)
        case emptyResponse

        var errorDescription: String? {
            switch self {
            case .invalidModel: "模型名稱無效，請到設定檢查。"
            case .server(429, _): "免費額度暫時用完，稍後再試，或到 AI Studio 查看額度。"
            case .server(400, _), .server(401, _), .server(403, _): "Gemini API Key 無法使用，請檢查設定及 AI Studio 專案。"
            case .server(404, _): "找不到這個 Gemini 模型，請到設定檢查模型名稱。"
            case .server(let code, let message): "Gemini 回覆錯誤 \(code)：\(message)"
            case .emptyResponse: "Gemini 沒有回傳文字，請換段文字再試。"
            }
        }
    }

    func generate(text: String, mode: ExplainMode, key: String) async throws -> String {
        let model = AppSettings.model
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.")
        guard !model.isEmpty, model.unicodeScalars.allSatisfy(allowed.contains) else {
            throw ClientError.invalidModel
        }
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
        let payload = Request(
            systemInstruction: Content(role: nil, parts: [Part(text: AppSettings.prompt(for: mode))]),
            contents: [Content(role: "user", parts: [Part(text: text)])],
            generationConfig: GenerationConfig(temperature: 0.2, maxOutputTokens: 800)
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONEncoder().encode(payload)
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as? HTTPURLResponse
        let decoded = try? JSONDecoder().decode(Response.self, from: data)
        guard let status = http?.statusCode, (200..<300).contains(status) else {
            throw ClientError.server(http?.statusCode ?? 0, decoded?.error?.message ?? "連線失敗")
        }
        let output = decoded?.candidates?.first?.content?.parts.compactMap(\.text).joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let output, !output.isEmpty else { throw ClientError.emptyResponse }
        // Flash-Lite sometimes slips simplified characters (时间) into Taiwan
        // Traditional Chinese output. Latin text passes through unchanged.
        return output.applyingTransform(StringTransform("Hans-Hant"), reverse: false) ?? output
    }
}
