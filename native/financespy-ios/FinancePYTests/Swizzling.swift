import Foundation

extension URLSessionConfiguration {
    @objc class func swizzled_default() -> URLSessionConfiguration {
        let config = self.swizzled_default() // Calls original
        config.protocolClasses = [MockURLProtocol.self] as [AnyClass] + (config.protocolClasses ?? [])
        return config
    }

    private static var hasSwizzled = false

    static func swizzleDefaultConfiguration() {
        guard !hasSwizzled else { return }
        hasSwizzled = true

        let originalSelector = #selector(getter: URLSessionConfiguration.default)
        let swizzledSelector = #selector(URLSessionConfiguration.swizzled_default)

        guard let originalMethod = class_getClassMethod(URLSessionConfiguration.self, originalSelector),
              let swizzledMethod = class_getClassMethod(URLSessionConfiguration.self, swizzledSelector) else {
            return
        }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
}
