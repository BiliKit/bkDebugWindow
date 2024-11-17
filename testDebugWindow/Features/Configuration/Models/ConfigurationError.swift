// MARK: - 错误定义
enum ConfigurationError: Error {
    case invalidPath
    case saveFailed(Error)
    case loadFailed(Error)
}
