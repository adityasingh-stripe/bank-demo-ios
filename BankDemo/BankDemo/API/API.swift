import Foundation

struct API {
    static func appInfo(baseURL: String? = nil) async -> Result<AppInfo, APIError> {
        let actualBaseURL: String
        if let baseURL = baseURL {
            actualBaseURL = baseURL
        } else {
            actualBaseURL = await AppSettings.shared.selectedServerBaseURL
        }
        return await apiRequest(path: "api/app_info", baseURL: actualBaseURL)
    }
    
    static func accountSession(merchantId: String? = nil, baseURL: String? = nil) async -> Result<AccountSessionResponse, APIError> {
        let actualBaseURL: String
        if let baseURL = baseURL {
            actualBaseURL = baseURL
        } else {
            actualBaseURL = await AppSettings.shared.selectedServerBaseURL
        }
        return await apiRequest(path: "api/account_session",
                         method: "POST",
                         headers: merchantId.map { ["account": $0] } ?? [:],
                         baseURL: actualBaseURL)
    }

    static func apiRequest<Response: Codable>(path: String,
                                              method: String = "GET",
                                              headers: [String: String] = [:],
                                              baseURL: String) async -> Result<Response, APIError> {
        guard let baseUrl = URL(string: baseURL) else {
            return .failure(.invalidURL)
        }
        let url = baseUrl.appendingPathComponent(path)
        print("INFO: API \(method) \(url)")
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.allHTTPHeaderFields = headers
        do {
            let decoder = JSONDecoder()
            let (data, response)  = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.networkError(error: URLError(.badServerResponse)))
            }
            print("INFO: API response \(httpResponse.statusCode) for \(method) \(path)")
            guard httpResponse.statusCode == 200 else {
                do {
                    return .failure(.responseError(response: try decoder.decode(APIErrorResponse.self, from: data)))
                } catch {
                    return .failure(.failedToParse(error: error))
                }
            }
            do {
                let decoded = try decoder.decode(Response.self, from: data)
                return .success(decoded)
            } catch {
                print("ERROR: JSON decoding failed for \(path): \(error)")
                return .failure(.failedToParse(error: error))
            }
        } catch {
            return .failure(.networkError(error: error))
        }
    }
}
