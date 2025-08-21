import Foundation

struct API {
    static func appInfo(baseURL: String? = nil) async -> Result<AppInfo, APIError> {
        let actualBaseURL: String
        if let baseURL = baseURL {
            actualBaseURL = baseURL
        } else {
            actualBaseURL = await AppSettings.shared.selectedServerBaseURL
        }
        
        print("INFO: Fetching app info from: \(actualBaseURL)")
        return await apiRequest(path: "api/app_info", baseURL: actualBaseURL)
    }
    
    static func accountSession(merchantId: String? = nil, baseURL: String? = nil) async -> Result<AccountSessionResponse, APIError> {
        let actualBaseURL: String
        if let baseURL = baseURL {
            actualBaseURL = baseURL
        } else {
            actualBaseURL = await AppSettings.shared.selectedServerBaseURL
        }
        
        let headers = merchantId.map { ["account": $0] } ?? [:]
        print("INFO: Creating account session for merchant: \(merchantId ?? "default")")
        
        return await apiRequest(path: "api/account_session",
                         method: "POST",
                         headers: headers,
                         baseURL: actualBaseURL)
    }

    static func apiRequest<Response: Codable>(path: String,
                                              method: String = "GET",
                                              headers: [String: String] = [:],
                                              baseURL: String) async -> Result<Response, APIError> {
        let startTime = Date()
        
                    guard let baseUrl = URL(string: baseURL) else {
            print("ERROR: Invalid base URL: \(baseURL)")
            return .failure(.invalidURL)
        }
        
        let url = baseUrl.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.allHTTPHeaderFields = headers
        
        // Add JSON content type for POST requests
        if method == "POST" && headers["Content-Type"] == nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        // Log the request
        print("INFO: API \(method) \(url.absoluteString)")
        
        do {
            let decoder = JSONDecoder()
            let (data, response) = try await URLSession.shared.data(for: request)
            let responseTime = Date().timeIntervalSince(startTime)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                let error = URLError(.badServerResponse)
                print("Bad server response for \(path)")
                return .failure(.networkError(error: error))
            }
            
            // Log the response
            print("INFO: API response \(httpResponse.statusCode) for \(url.absoluteString)")
            
            guard httpResponse.statusCode == 200 else {
                do {
                    let errorResponse = try decoder.decode(APIErrorResponse.self, from: data)
                    print("API error response: \(errorResponse)")
                    return .failure(.responseError(response: errorResponse))
                } catch {
                    print("Failed to parse error response: \(error)")
                    return .failure(.failedToParse(error: error))
                }
            }
            
            do {
                let decoded = try decoder.decode(Response.self, from: data)
                print("Successfully decoded response for \(path)")
                return .success(decoded)
            } catch {
                print("JSON decoding failed for \(path): \(error)")
                
                // Log the raw response for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Raw response data: \(responseString)")
                }
                
                return .failure(.failedToParse(error: error))
            }
        } catch {
            let responseTime = Date().timeIntervalSince(startTime)
            print("Network error for \(path) after \(String(format: "%.3f", responseTime))s: \(error)")
            return .failure(.networkError(error: error))
        }
    }
}
