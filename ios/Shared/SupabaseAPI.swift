import Foundation

enum SupabaseAPI {
    private static var _baseURL: String?
    private static var _anonKey: String?

    static var baseURL: String {
        if let cached = _baseURL { return cached }
        guard let url = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String, !url.isEmpty else {
            fatalError("SUPABASE_URL not configured in Info.plist. Copy Secrets.xcconfig.example to Secrets.xcconfig and set your values.")
        }
        _baseURL = url
        return url
    }

    static var anonKey: String {
        if let cached = _anonKey { return cached }
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String, !key.isEmpty else {
            fatalError("SUPABASE_ANON_KEY not configured in Info.plist. Copy Secrets.xcconfig.example to Secrets.xcconfig and set your values.")
        }
        _anonKey = key
        return key
    }

    // MARK: - Errors

    enum APIError: LocalizedError {
        case invalidURL
        case httpError(statusCode: Int, body: String)
        case networkError(Error)
        case decodingError

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid API URL"
            case .httpError(let code, let body):
                return "HTTP \(code): \(body)"
            case .networkError(let error):
                return error.localizedDescription
            case .decodingError:
                return "Failed to decode response"
            }
        }
    }

    // MARK: - POST Helpers

    private static func makePostRequest(path: String, body: Any, upsert: Bool = false) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(upsert ? "return=minimal,resolution=merge-duplicates" : "return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private static func executePost(_ request: URLRequest) async throws {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.httpError(statusCode: 0, body: "Not an HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.httpError(statusCode: httpResponse.statusCode, body: body)
        }
    }

    // MARK: - GET Helpers

    private static func makeGetRequest(path: String, queryItems: [URLQueryItem] = []) throws -> URLRequest {
        guard var components = URLComponents(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private static func executeGet<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.httpError(statusCode: 0, body: "Not an HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.httpError(statusCode: httpResponse.statusCode, body: body)
        }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError
        }
    }

    // MARK: - Data Models

    struct PollRow: Decodable, Identifiable, Hashable {
        let id: String
        let title: String
        let durationMinutes: Int
        let status: String
        let createdAt: String
        let creatorSessionId: String?
        let finalizedSlotId: String?

        var createdDate: Date? {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.date(from: createdAt)
        }
    }

    struct TimeSlotRow: Decodable, Identifiable {
        let id: String
        let pollId: String
        let day: String
        let startTime: String
        let endTime: String
    }

    struct ResponseRow: Decodable {
        let id: String?
        let pollId: String
        let slotId: String
        let sessionId: String
        let availability: String
    }

    struct ParticipantRow: Decodable {
        let pollId: String
        let sessionId: String
        let displayName: String?
    }

    // MARK: - Write: Poll

    static func createPoll(
        id: String,
        title: String,
        durationMinutes: Int,
        creatorSessionId: String
    ) async throws {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let now = isoFormatter.string(from: Date())

        let body: [String: Any] = [
            "id": id,
            "title": title,
            "duration_minutes": durationMinutes,
            "status": "open",
            "created_at": now,
            "creator_session_id": creatorSessionId
        ]

        let request = try makePostRequest(path: "/polls", body: body)
        try await executePost(request)
    }

    // MARK: - Write: Time Slots

    static func insertTimeSlots(pollId: String, slots: [[String: String]]) async throws {
        guard !slots.isEmpty else { return }

        let body: [[String: Any]] = slots.map { slot in
            [
                "id": slot["id"] ?? UUID().uuidString,
                "poll_id": pollId,
                "day": slot["day"] ?? "",
                "start_time": slot["start_time"] ?? "",
                "end_time": slot["end_time"] ?? ""
            ]
        }

        let request = try makePostRequest(path: "/time_slots", body: body)
        try await executePost(request)
    }

    // MARK: - Write: Availability Blocks

    static func insertAvailabilityBlocks(pollId: String, blocks: [[String: String]]) async throws {
        guard !blocks.isEmpty else { return }

        let body: [[String: Any]] = blocks.map { block in
            [
                "id": block["id"] ?? UUID().uuidString,
                "poll_id": pollId,
                "day": block["day"] ?? "",
                "start_time": block["start_time"] ?? "",
                "end_time": block["end_time"] ?? ""
            ]
        }

        let request = try makePostRequest(path: "/availability_blocks", body: body)
        try await executePost(request)
    }

    // MARK: - Write: Participants

    static func insertParticipant(pollId: String, sessionId: String, displayName: String) async throws {
        let body: [String: Any] = [
            "poll_id": pollId,
            "session_id": sessionId,
            "display_name": displayName
        ]

        // Use on_conflict for proper upsert - unique constraint is on (poll_id, session_id)
        let request = try makePostRequest(
            path: "/participants?on_conflict=poll_id,session_id",
            body: body,
            upsert: true
        )
        try await executePost(request)
    }

    // MARK: - Write: Responses

    static func submitResponse(pollId: String, slotId: String, sessionId: String, availability: String) async throws {
        let body: [String: Any] = [
            "poll_id": pollId,
            "slot_id": slotId,
            "session_id": sessionId,
            "availability": availability
        ]

        // Use on_conflict for proper upsert - unique constraint is on (poll_id, slot_id, session_id)
        let request = try makePostRequest(
            path: "/responses?on_conflict=poll_id,slot_id,session_id",
            body: body,
            upsert: true
        )
        try await executePost(request)
    }

    // MARK: - Read: Poll

    static func fetchPoll(id: String) async throws -> PollRow? {
        let request = try makeGetRequest(path: "/polls", queryItems: [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "id", value: "eq.\(id)"),
            URLQueryItem(name: "archived_at", value: "is.null"),
            URLQueryItem(name: "limit", value: "1")
        ])
        let rows: [PollRow] = try await executeGet(request)
        return rows.first
    }

    // MARK: - Read: Polls by Session

    static func fetchPollsCreatedBy(sessionId: String) async throws -> [PollRow] {
        let request = try makeGetRequest(path: "/polls", queryItems: [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "creator_session_id", value: "eq.\(sessionId)"),
            URLQueryItem(name: "archived_at", value: "is.null"),
            URLQueryItem(name: "order", value: "created_at.desc")
        ])
        return try await executeGet(request)
    }

    static func fetchPollsRespondedToBy(sessionId: String) async throws -> [PollRow] {
        // First get poll IDs from responses
        let responsesRequest = try makeGetRequest(path: "/responses", queryItems: [
            URLQueryItem(name: "select", value: "poll_id"),
            URLQueryItem(name: "session_id", value: "eq.\(sessionId)")
        ])

        struct PollIdRow: Decodable {
            let pollId: String
        }

        let responses: [PollIdRow] = try await executeGet(responsesRequest)
        let pollIds = Array(Set(responses.map { $0.pollId }))

        guard !pollIds.isEmpty else { return [] }

        // Fetch the polls
        let pollIdsString = pollIds.joined(separator: ",")
        let pollsRequest = try makeGetRequest(path: "/polls", queryItems: [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "id", value: "in.(\(pollIdsString))"),
            URLQueryItem(name: "archived_at", value: "is.null"),
            URLQueryItem(name: "order", value: "created_at.desc")
        ])
        return try await executeGet(pollsRequest)
    }

    // MARK: - Read: Time Slots

    static func fetchTimeSlots(pollId: String) async throws -> [TimeSlotRow] {
        let request = try makeGetRequest(path: "/time_slots", queryItems: [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "poll_id", value: "eq.\(pollId)"),
            URLQueryItem(name: "order", value: "day.asc,start_time.asc")
        ])
        return try await executeGet(request)
    }

    // MARK: - Read: Responses

    static func fetchResponses(pollId: String) async throws -> [ResponseRow] {
        let request = try makeGetRequest(path: "/responses", queryItems: [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "poll_id", value: "eq.\(pollId)")
        ])
        return try await executeGet(request)
    }

    // MARK: - Read: Participants

    static func fetchParticipants(pollId: String) async throws -> [ParticipantRow] {
        let request = try makeGetRequest(path: "/participants", queryItems: [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "poll_id", value: "eq.\(pollId)")
        ])
        return try await executeGet(request)
    }

    // MARK: - Read: Response Count for Poll

    static func fetchResponseCount(pollId: String) async throws -> Int {
        let request = try makeGetRequest(path: "/participants", queryItems: [
            URLQueryItem(name: "select", value: "session_id"),
            URLQueryItem(name: "poll_id", value: "eq.\(pollId)")
        ])
        let participants: [ParticipantRow] = try await executeGet(request)
        return participants.count
    }

    // MARK: - Write: Push Token

    static func registerPushToken(sessionId: String, token: String) async throws {
        let body: [String: Any] = [
            "session_id": sessionId,
            "token": token,
            "platform": "ios"
        ]
        // Upsert on (session_id, token) unique constraint
        let request = try makePostRequest(
            path: "/push_tokens?on_conflict=session_id,token",
            body: body,
            upsert: true
        )
        try await executePost(request)
    }

    // MARK: - Write: Finalize Poll

    static func finalizePoll(pollId: String, slotId: String) async throws {
        guard var components = URLComponents(string: "\(baseURL)/polls") else {
            throw APIError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "id", value: "eq.\(pollId)")]
        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")

        // Use "finalized" status - matches database CHECK constraint
        let body: [String: Any] = [
            "status": "finalized",
            "finalized_slot_id": slotId
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.httpError(statusCode: 0, body: "Not an HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            // Parse error message for better display
            var errorMessage = "Unknown error"
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? String {
                errorMessage = message
            } else if let bodyStr = String(data: data, encoding: .utf8) {
                errorMessage = bodyStr
            }
            throw APIError.httpError(statusCode: httpResponse.statusCode, body: errorMessage)
        }
    }
}
