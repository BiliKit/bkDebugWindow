enum Environment {
    #if DEBUG
    static let isDevelopment = true
    static let apiBaseURL = "http://dev-api.example.com"
    #else
    static let isDevelopment = false
    static let apiBaseURL = "https://api.example.com"
    #endif
}